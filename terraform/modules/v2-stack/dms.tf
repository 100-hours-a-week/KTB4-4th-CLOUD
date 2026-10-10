# Optional: enable_dms=true only after source credentials, CDC settings, and DMS roles are prepared.
resource "aws_security_group" "dms" {
  count       = var.enable_dms ? 1 : 0
  name_prefix = "needu-${var.environment}-dms-"
  vpc_id      = data.aws_vpc.selected.id
}
resource "aws_vpc_security_group_egress_rule" "dms_out" {
  count             = var.enable_dms ? 1 : 0
  security_group_id = aws_security_group.dms[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_vpc_security_group_ingress_rule" "mysql_dms" {
  count                        = var.enable_dms ? 1 : 0
  security_group_id            = aws_security_group.mysql.id
  referenced_security_group_id = aws_security_group.dms[0].id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "postgres_dms" {
  count                        = var.enable_dms ? 1 : 0
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = aws_security_group.dms[0].id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}
resource "aws_dms_replication_subnet_group" "main" {
  count                                = var.enable_dms ? 1 : 0
  replication_subnet_group_id          = "needu-${var.environment}-dms"
  replication_subnet_group_description = "NeedU migration subnets"
  subnet_ids                           = local.db_subnet_ids
}
resource "aws_dms_replication_instance" "main" {
  count                       = var.enable_dms ? 1 : 0
  replication_instance_id     = "needu-${var.environment}-dms"
  replication_instance_class  = var.dms_replication_instance_class
  allocated_storage           = 50
  publicly_accessible         = false
  replication_subnet_group_id = aws_dms_replication_subnet_group.main[0].id
  vpc_security_group_ids      = [aws_security_group.dms[0].id]
  multi_az                    = false
  depends_on                  = [aws_dms_replication_subnet_group.main]
}
resource "aws_dms_endpoint" "source_mysql" {
  count                           = var.enable_dms ? 1 : 0
  endpoint_id                     = "needu-${var.environment}-src-mysql"
  endpoint_type                   = "source"
  engine_name                     = "mysql"
  server_name                     = var.dms_source_mysql_host
  port                            = var.dms_source_mysql_port
  secrets_manager_arn             = var.dms_source_mysql_secret_arn
  secrets_manager_access_role_arn = var.dms_endpoint_access_role_arn
}
resource "aws_dms_endpoint" "source_postgres" {
  count                           = var.enable_dms ? 1 : 0
  endpoint_id                     = "needu-${var.environment}-src-postgres"
  endpoint_type                   = "source"
  engine_name                     = "postgres"
  server_name                     = var.dms_source_postgres_host
  port                            = var.dms_source_postgres_port
  secrets_manager_arn             = var.dms_source_postgres_secret_arn
  secrets_manager_access_role_arn = var.dms_endpoint_access_role_arn
}
resource "aws_dms_endpoint" "target_mysql" {
  count                           = var.enable_dms ? 1 : 0
  endpoint_id                     = "needu-${var.environment}-dst-mysql"
  endpoint_type                   = "target"
  engine_name                     = "mysql"
  server_name                     = aws_db_instance.mysql.address
  port                            = 3306
  secrets_manager_arn             = aws_db_instance.mysql.master_user_secret[0].secret_arn
  secrets_manager_access_role_arn = var.dms_endpoint_access_role_arn
}
resource "aws_dms_endpoint" "target_postgres" {
  count                           = var.enable_dms ? 1 : 0
  endpoint_id                     = "needu-${var.environment}-dst-postgres"
  endpoint_type                   = "target"
  engine_name                     = "postgres"
  server_name                     = aws_db_instance.postgres.address
  port                            = 5432
  secrets_manager_arn             = aws_db_instance.postgres.master_user_secret[0].secret_arn
  secrets_manager_access_role_arn = var.dms_endpoint_access_role_arn
}
resource "aws_dms_replication_task" "mysql" {
  count                    = var.enable_dms ? 1 : 0
  replication_task_id      = "needu-${var.environment}-mysql"
  migration_type           = "full-load-and-cdc"
  replication_instance_arn = aws_dms_replication_instance.main[0].replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source_mysql[0].endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target_mysql[0].endpoint_arn
  table_mappings           = jsonencode({ rules = [{ rule-type = "selection", rule-id = "1", rule-name = "all", object-locator = { schema-name = "needu", table-name = "%" }, rule-action = "include" }] })
  start_replication_task   = false
}
resource "aws_dms_replication_task" "postgres" {
  count                    = var.enable_dms ? 1 : 0
  replication_task_id      = "needu-${var.environment}-postgres"
  migration_type           = "full-load-and-cdc"
  replication_instance_arn = aws_dms_replication_instance.main[0].replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source_postgres[0].endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target_postgres[0].endpoint_arn
  table_mappings           = jsonencode({ rules = [{ rule-type = "selection", rule-id = "1", rule-name = "public", object-locator = { schema-name = "public", table-name = "%" }, rule-action = "include" }] })
  start_replication_task   = false
}
