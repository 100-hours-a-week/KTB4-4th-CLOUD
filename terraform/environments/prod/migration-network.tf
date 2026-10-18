# V1과 V2가 이미 공유하는 VPC Peering을 통해 Prod ALB가 V1 Nginx에 접근합니다.
resource "aws_route" "v2_prod_public_to_v1" {
  route_table_id            = module.v2.public_route_table_id
  destination_cidr_block    = var.v1_prod_migration_network.vpc_cidr
  vpc_peering_connection_id = var.v1_prod_migration_network.peering_connection_id
}

resource "aws_vpc_security_group_egress_rule" "prod_alb_to_v1_https" {
  security_group_id = module.v2.alb_security_group_id
  cidr_ipv4         = "${var.v1_prod_migration_network.app_private_ip}/32"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Shared prod ALB forwards HTTPS traffic to V1 prod"
}

resource "aws_vpc_security_group_ingress_rule" "v1_prod_https_from_v2_alb" {
  security_group_id            = var.v1_prod_migration_network.security_group_id
  referenced_security_group_id = module.v2.alb_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Shared prod ALB reaches V1 prod Nginx"
}
