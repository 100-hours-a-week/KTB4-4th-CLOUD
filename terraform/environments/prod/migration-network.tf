# 기존 별도 Route의 상태만 해제하고, 같은 경로는 V2 네트워크 모듈의 Route Table에서 계속 관리합니다.
removed {
  from = aws_route.v2_prod_public_to_v1

  lifecycle {
    destroy = false
  }
}

# DMS Replication Instance가 배치될 Prod DB 서브넷에서 V1 MySQL로 접근합니다.
resource "aws_route" "v2_prod_db_to_v1" {
  route_table_id            = module.v2.db_route_table_id
  destination_cidr_block    = var.v1_prod_migration_network.vpc_cidr
  vpc_peering_connection_id = var.v1_prod_migration_network.peering_connection_id
}

# DMS Console에서 생성할 Prod 전용 Replication Instance에 연결합니다.
resource "aws_security_group" "prod_dms" {
  name_prefix = "needu-prod-dms-"
  description = "V1 to V2 prod DMS migration"
  vpc_id      = module.v2.vpc_id

  tags = {
    Name    = "needu-prod-dms"
    Purpose = "DMSMigration"
  }
}

resource "aws_vpc_security_group_egress_rule" "prod_dms_outbound" {
  security_group_id = aws_security_group.prod_dms.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Prod DMS만 V1 Prod MySQL에 접근할 수 있도록 허용합니다.
resource "aws_vpc_security_group_ingress_rule" "v1_prod_mysql_from_dms" {
  security_group_id            = var.v1_prod_migration_network.security_group_id
  referenced_security_group_id = aws_security_group.prod_dms.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "V2 prod DMS reads V1 prod MySQL"
}

# Prod DMS만 V2 Prod MySQL RDS에 적재할 수 있도록 허용합니다.
resource "aws_vpc_security_group_ingress_rule" "v2_prod_mysql_from_dms" {
  security_group_id            = module.v2.mysql_security_group_id
  referenced_security_group_id = aws_security_group.prod_dms.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "V2 prod DMS writes V2 prod MySQL"
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

output "prod_dms_network" {
  description = "DMS Console 설정에 사용할 Prod 네트워크 정보"
  value = {
    security_group_id = aws_security_group.prod_dms.id
    subnet_ids        = module.v2.db_subnet_ids
    source_mysql_host = var.v1_prod_migration_network.mysql_private_ip
    target_mysql_host = module.v2.mysql_address
  }
}
