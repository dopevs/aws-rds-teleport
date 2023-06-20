data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = "ap-southeast-1"

}

# Create vpc for teleport host
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "teleport-vpc"
  cidr = "192.168.0.0/16"

  azs              = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  private_subnets  = ["192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24"]
  public_subnets   = ["192.168.101.0/24", "192.168.102.0/24", "192.168.103.0/24"]
  database_subnets = ["192.168.201.0/24", "192.168.202.0/24", "192.168.203.0/24"]


  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Create security groups for teleport host
resource "aws_security_group" "allow_web_ssh" {
  name        = "TeleportSG"
  description = "Allow Http,TLS,SSH inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow ssh traffic from public"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow http traffic from public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow https traffic from public"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "TeleportSG"
  }
}

# Security group for postgres
resource "aws_security_group" "allow_db" {
  name        = "PostgresSG"
  description = "SG for postgres db"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow db traffic from public subnet"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = module.vpc.public_subnets_cidr_blocks
  }

  tags = {
    Name = "PostgresSG"
  }
}

# Create ubuntu ec2 to host teleport
module "ec2_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name                   = "teleport-instance"
  ami                    = "ami-0df7a207adb9748c7" // ubuntu ami on ap-southeast-1 (Singapore)
  instance_type          = "t3.medium"
  key_name               = "WaiYan"
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.allow_web_ssh.id]
  availability_zone      = element(module.vpc.azs, 0)
  subnet_id              = element(module.vpc.public_subnets, 0)
  iam_instance_profile   = aws_iam_instance_profile.teleport.name

  root_block_device = [
    {
      encrypted   = true
      volume_type = "gp3"
      throughput  = 200
      volume_size = 30
    },
  ]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_eip" "teleport_ip" {
  instance = module.ec2_instance.id
  domain   = "vpc"
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier                          = "main-postgres"
  engine                              = "postgres"
  engine_version                      = "14"
  family                              = "postgres14" # DB parameter group
  major_engine_version                = "14"         # DB option group
  instance_class                      = "db.t3.small"
  allocated_storage                   = 20
  max_allocated_storage               = 100
  create_random_password              = false
  iam_database_authentication_enabled = true
  db_name                             = "postgres"
  username                            = "postgres"
  password                            = "postgresSQL14"
  db_subnet_group_name                = module.vpc.database_subnet_group
  vpc_security_group_ids              = [aws_security_group.allow_db.id]
}

# IAM Role for teleport
resource "aws_iam_role" "teleport" {
  name = "teleport-role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {"Service": "ec2.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

}

resource "aws_iam_role_policy" "teleport" {
  name = "teleport-policy"
  role = aws_iam_role.teleport.id

  policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
     {
       "Effect": "Allow",
       "Action": "sts:AssumeRole",
       "Resource": "${aws_iam_role.teleport.arn}"
     },
     {
       "Effect": "Allow",
       "Action": [
         "rds-db:connect"
      ],
       "Resource": ["arn:aws:rds-db:${local.region}:${local.account_id}:dbuser:${module.db.db_instance_resource_id}/*"]
     }
   ]
 }

EOF

}

# Instance profile
resource "aws_iam_instance_profile" "teleport" {
  name       = "teleport"
  role       = aws_iam_role.teleport.name
  depends_on = [aws_iam_role_policy.teleport]
}
