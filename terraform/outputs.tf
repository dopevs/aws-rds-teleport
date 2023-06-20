output "public_ip" {
  value = aws_eip.teleport_ip.public_ip
}
