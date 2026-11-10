resource "aws_vpc_security_group_ingress_rule" "prod_mysql_from_v3_eks" {
  security_group_id = module.v2.mysql_security_group_id

  ip_protocol = "tcp"
  from_port   = 3306
  to_port     = 3306

  referenced_security_group_id = "sg-06867e8d11c60ce9d"

  description = "Allow V3 Production EKS to access MySQL"
}
resource "aws_vpc_security_group_ingress_rule" "prod_postgres_from_v3_eks" {
  security_group_id = module.v2.postgres_security_group_id

  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432

  referenced_security_group_id = "sg-06867e8d11c60ce9d"

  description = "Allow V3 Production EKS to access PostgreSQL"
}
