CREATE USER "teleport-read-only"; 
GRANT rds_iam TO "teleport-read-only";
CREATE USER "teleport-read-write"; 
GRANT rds_iam TO "teleport-read-write";



grant select ON ALL TABLES IN SCHEMA public to "teleport-read-only";
grant usage, select ON ALL sequences in SCHEMA public to "teleport-read-only";
alter default privileges in schema public grant select on tables to "teleport-read-only";
alter default privileges in schema public grant select on sequences to "teleport-read-only";



grant select, insert, update, delete ON ALL TABLES IN SCHEMA public to "teleport-read-write";
grant usage, select, update ON ALL sequences in SCHEMA public to "teleport-read-write";
alter default privileges in schema public grant select, insert, update, delete on tables to "teleport-read-write";
alter default privileges in schema public grant usage, select, update on sequences to "teleport-read-write";
