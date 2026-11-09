resource "aws_security_group" "alb" {
  count = var.enable_ecs_applications ? 1 : 0

  name_prefix = "needu-${var.environment}-alb-"
  description = "Public HTTPS ingress"
  vpc_id      = data.aws_vpc.selected.id
  tags        = { Name = "needu-${var.environment}-alb" }
}
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count = var.enable_ecs_applications ? 1 : 0

  security_group_id = aws_security_group.alb[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  count = var.enable_ecs_applications ? 1 : 0

  security_group_id = aws_security_group.alb[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "alb_to_fe" {
  count = var.enable_ecs_applications ? 1 : 0

  security_group_id            = aws_security_group.alb[0].id
  referenced_security_group_id = aws_security_group.fe[0].id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "alb_to_be" {
  count = var.enable_ecs_applications ? 1 : 0

  security_group_id            = aws_security_group.alb[0].id
  referenced_security_group_id = aws_security_group.be[0].id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}
resource "aws_security_group" "fe" {
  count = var.enable_ecs_applications ? 1 : 0

  name_prefix = "needu-${var.environment}-fe-"
  vpc_id      = data.aws_vpc.selected.id
}
resource "aws_security_group" "be" {
  count = var.enable_ecs_applications ? 1 : 0

  name_prefix = "needu-${var.environment}-be-"
  vpc_id      = data.aws_vpc.selected.id
}
resource "aws_security_group" "ai" {
  count = var.enable_ecs_applications ? 1 : 0

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
  count = var.enable_ecs_applications ? 1 : 0

  security_group_id            = aws_security_group.fe[0].id
  referenced_security_group_id = aws_security_group.alb[0].id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "be_from_alb" {
  count = var.enable_ecs_applications ? 1 : 0

  security_group_id            = aws_security_group.be[0].id
  referenced_security_group_id = aws_security_group.alb[0].id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "ai_from_be" {
  count = var.enable_ecs_applications ? 1 : 0

  security_group_id            = aws_security_group.ai[0].id
  referenced_security_group_id = aws_security_group.be[0].id
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "mysql_from_be" {
  count = var.enable_ecs_applications ? 1 : 0

  security_group_id            = aws_security_group.mysql.id
  referenced_security_group_id = aws_security_group.be[0].id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "postgres_from_ai" {
  count = var.enable_ecs_applications ? 1 : 0

  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = aws_security_group.ai[0].id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "redis_from_be" {
  count = var.enable_ecs_applications ? 1 : 0

  security_group_id            = aws_security_group.redis.id
  referenced_security_group_id = aws_security_group.be[0].id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "redis_from_ai" {
  count = var.enable_ecs_applications ? 1 : 0

  security_group_id            = aws_security_group.redis.id
  referenced_security_group_id = aws_security_group.ai[0].id
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
  for_each = merge(var.enable_ecs_applications ? {
    fe = aws_security_group.fe[0].id
    be = aws_security_group.be[0].id
    ai = aws_security_group.ai[0].id
    } : {}, {
    ai_catalog_sync   = aws_security_group.ai_catalog_sync.id
    ai_catalog_import = aws_security_group.ai_catalog_import.id
  })
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
