# V1 Staging EC2 MySQL과 V2 Staging DMS가 Private IP로 통신하도록 VPC를 연결합니다.
resource "aws_vpc_peering_connection" "v1_staging" {
  vpc_id      = module.v2.vpc_id
  peer_vpc_id = var.v1_staging_migration_network.vpc_id
  auto_accept = true

  tags = {
    Name    = "needu-staging-v1-v2-migration"
    Purpose = "DMSMigration"
  }
}

# V2 DB 서브넷의 DMS가 V1 Staging 네트워크로 요청을 보낼 수 있게 합니다.
resource "aws_route" "v2_db_to_v1_staging" {
  route_table_id            = module.v2.db_route_table_id
  destination_cidr_block    = var.v1_staging_migration_network.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.v1_staging.id
}

# V1 Staging EC2가 DMS 응답을 V2 VPC로 돌려보낼 수 있게 합니다.
resource "aws_route" "v1_staging_to_v2" {
  route_table_id            = var.v1_staging_migration_network.route_table_id
  destination_cidr_block    = "10.1.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.v1_staging.id
}

# Console에서 생성할 DMS Replication Instance에 연결할 전용 보안 그룹입니다.
resource "aws_security_group" "dms" {
  name_prefix = "needu-staging-dms-"
  description = "V1 to V2 staging DMS migration"
  vpc_id      = module.v2.vpc_id

  tags = {
    Name    = "needu-staging-dms"
    Purpose = "DMSMigration"
  }
}

# DMS가 소스·대상 DB와 AWS DMS 제어 영역에 통신할 수 있게 합니다.
resource "aws_vpc_security_group_egress_rule" "dms_outbound" {
  security_group_id = aws_security_group.dms.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# V1 Staging EC2 MySQL은 DMS 보안 그룹에서 오는 요청만 허용합니다.
resource "aws_vpc_security_group_ingress_rule" "v1_mysql_from_dms" {
  security_group_id            = var.v1_staging_migration_network.security_group_id
  referenced_security_group_id = aws_security_group.dms.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "V2 staging DMS reads V1 staging MySQL"

  depends_on = [aws_vpc_peering_connection.v1_staging]
}

# V2 Staging MySQL은 같은 DMS 보안 그룹의 적재 요청만 추가로 허용합니다.
resource "aws_vpc_security_group_ingress_rule" "v2_mysql_from_dms" {
  security_group_id            = module.v2.mysql_security_group_id
  referenced_security_group_id = aws_security_group.dms.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "V2 staging DMS writes V2 staging MySQL"
}

output "dms_network" {
  description = "DMS Console 설정에 사용할 Staging 네트워크 정보"
  value = {
    security_group_id = aws_security_group.dms.id
    subnet_ids        = module.v2.db_subnet_ids
    source_mysql_host = var.v1_staging_migration_network.mysql_private_ip
  }
}
