# 기존 별도 Route의 상태만 해제하고, 같은 경로는 V2 네트워크 모듈의 Route Table에서 계속 관리합니다.
removed {
  from = aws_route.v2_prod_public_to_v1

  lifecycle {
    destroy = false
  }
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
