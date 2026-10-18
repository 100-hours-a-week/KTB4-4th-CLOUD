# 기존 Dev SSM Bastion을 재사용해 Prod MySQL RDS에 접근합니다.
locals {
  shared_ssm_bastion_sg_id = "sg-034208f09ce526099"
}

resource "aws_vpc_security_group_egress_rule" "ssm_to_prod_mysql" {
  security_group_id = local.shared_ssm_bastion_sg_id

  description = "Shared SSM Bastion to Prod MySQL"
  ip_protocol = "tcp"
  from_port   = 3306
  to_port     = 3306

  referenced_security_group_id = module.v2.mysql_security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "prod_mysql_from_ssm" {
  security_group_id = module.v2.mysql_security_group_id

  description = "Allow MySQL access from SSM bastion"
  ip_protocol = "tcp"
  from_port   = 3306
  to_port     = 3306

  referenced_security_group_id = local.shared_ssm_bastion_sg_id
}
