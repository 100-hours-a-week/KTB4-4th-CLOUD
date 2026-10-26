# ============================================================
# NeedU V2 Staging - Shared SSM Bastion Access
#
# Reuse existing Dev SSM Bastion EC2.
# Allow access to Staging MySQL / PostgreSQL RDS.
# ============================================================

locals {
  shared_ssm_bastion_sg_id = "sg-034208f09ce526099"
}

# Bastion -> Staging MySQL (3306)
resource "aws_vpc_security_group_egress_rule" "ssm_to_staging_mysql" {
  security_group_id = local.shared_ssm_bastion_sg_id

  description = "Shared SSM Bastion to Staging MySQL"

  ip_protocol = "tcp"
  from_port   = 3306
  to_port     = 3306

  referenced_security_group_id = module.v2.mysql_security_group_id
}

# Staging MySQL <- Bastion (3306)
resource "aws_vpc_security_group_ingress_rule" "staging_mysql_from_ssm" {
  security_group_id = module.v2.mysql_security_group_id

  description = "Allow Shared SSM Bastion to Staging MySQL"

  ip_protocol = "tcp"
  from_port   = 3306
  to_port     = 3306

  referenced_security_group_id = local.shared_ssm_bastion_sg_id
}

# Bastion -> Staging PostgreSQL (5432)
resource "aws_vpc_security_group_egress_rule" "ssm_to_staging_postgres" {
  security_group_id = local.shared_ssm_bastion_sg_id

  description = "Shared SSM Bastion to Staging PostgreSQL"

  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432

  referenced_security_group_id = module.v2.postgres_security_group_id
}

# Staging PostgreSQL <- Bastion (5432)
resource "aws_vpc_security_group_ingress_rule" "staging_postgres_from_ssm" {
  security_group_id = module.v2.postgres_security_group_id

  description = "Allow Shared SSM Bastion to Staging PostgreSQL"

  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432

  referenced_security_group_id = local.shared_ssm_bastion_sg_id
}

# Bastion -> Staging AI API (8000)
resource "aws_vpc_security_group_egress_rule" "ssm_to_staging_ai" {
  security_group_id = local.shared_ssm_bastion_sg_id

  description = "Shared SSM Bastion to Staging AI API"

  ip_protocol = "tcp"
  from_port   = 8000
  to_port     = 8000

  referenced_security_group_id = module.v2.ecs_security_group_ids["ai"]
}

# Staging AI API <- Bastion (8000)
resource "aws_vpc_security_group_ingress_rule" "staging_ai_from_ssm" {
  security_group_id = module.v2.ecs_security_group_ids["ai"]

  description = "Allow Shared SSM Bastion to Staging AI API"

  ip_protocol = "tcp"
  from_port   = 8000
  to_port     = 8000

  referenced_security_group_id = local.shared_ssm_bastion_sg_id
}
