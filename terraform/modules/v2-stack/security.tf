resource "aws_security_group" "alb" {
  name_prefix = "needu-${var.environment}-alb-"
  description = "Public HTTPS ingress"
  vpc_id      = data.aws_vpc.selected.id
  tags        = { Name = "needu-${var.environment}-alb" }
}
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "alb_to_fe" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.fe.id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "alb_to_be" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.be.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}
resource "aws_security_group" "fe" {
  name_prefix = "needu-${var.environment}-fe-"
  vpc_id      = data.aws_vpc.selected.id
}
resource "aws_security_group" "be" {
  name_prefix = "needu-${var.environment}-be-"
  vpc_id      = data.aws_vpc.selected.id
}
resource "aws_security_group" "ai" {
  name_prefix = "needu-${var.environment}-ai-"
  vpc_id      = data.aws_vpc.selected.id
}
resource "aws_security_group" "ai_catalog_sync" {
  name_prefix = "needu-${var.environment}-ai-catalog-sync-"
  description = "Catalog sync batch"
  vpc_id      = data.aws_vpc.selected.id
  tags        = { Name = "needu-${var.environment}-ai-catalog-sync-sg" }
}
resource "aws_security_group" "ai_catalog_import" {
  name_prefix = "needu-${var.environment}-ai-catalog-import-"
  description = "Catalog import batch"
  vpc_id      = data.aws_vpc.selected.id
  tags        = { Name = "needu-${var.environment}-ai-catalog-import-sg" }
}
resource "aws_security_group" "mysql" {
  name_prefix = "needu-${var.environment}-mysql-"
  vpc_id      = data.aws_vpc.selected.id
}
resource "aws_security_group" "postgres" {
  name_prefix = "needu-${var.environment}-postgres-"
  vpc_id      = data.aws_vpc.selected.id
}
resource "aws_security_group" "redis" {
  name_prefix = "needu-${var.environment}-redis-"
  vpc_id      = data.aws_vpc.selected.id
}
resource "aws_vpc_security_group_ingress_rule" "fe_from_alb" {
  security_group_id            = aws_security_group.fe.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "be_from_alb" {
  security_group_id            = aws_security_group.be.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "ai_from_be" {
  security_group_id            = aws_security_group.ai.id
  referenced_security_group_id = aws_security_group.be.id
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "mysql_from_be" {
  security_group_id            = aws_security_group.mysql.id
  referenced_security_group_id = aws_security_group.be.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "postgres_from_ai" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = aws_security_group.ai.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "redis_from_be" {
  security_group_id            = aws_security_group.redis.id
  referenced_security_group_id = aws_security_group.be.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "redis_from_ai" {
  security_group_id            = aws_security_group.redis.id
  referenced_security_group_id = aws_security_group.ai.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "mysql_from_ai_catalog_sync" {
  security_group_id            = aws_security_group.mysql.id
  referenced_security_group_id = aws_security_group.ai_catalog_sync.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "Catalog sync batch reads MySQL"
}
resource "aws_vpc_security_group_ingress_rule" "postgres_from_ai_catalog_sync" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = aws_security_group.ai_catalog_sync.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Catalog sync batch writes PostgreSQL"
}
resource "aws_vpc_security_group_ingress_rule" "postgres_from_ai_catalog_import" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = aws_security_group.ai_catalog_import.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Catalog import batch writes PostgreSQL"
}
resource "aws_vpc_security_group_egress_rule" "app_outbound" {
  for_each = {
    fe                = aws_security_group.fe.id
    be                = aws_security_group.be.id
    ai                = aws_security_group.ai.id
    ai_catalog_sync   = aws_security_group.ai_catalog_sync.id
    ai_catalog_import = aws_security_group.ai_catalog_import.id
  }
  security_group_id = each.value
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_vpc_security_group_egress_rule" "db_mysql_outbound" {
  security_group_id = aws_security_group.mysql.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_vpc_security_group_egress_rule" "db_postgres_outbound" {
  security_group_id = aws_security_group.postgres.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_vpc_security_group_egress_rule" "redis_outbound" {
  security_group_id = aws_security_group.redis.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
