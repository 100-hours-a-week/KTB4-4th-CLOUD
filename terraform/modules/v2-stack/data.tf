resource "aws_db_subnet_group" "main" {
  name       = "needu-${var.environment}-db-subnets"
  subnet_ids = local.db_subnet_ids
}
resource "aws_db_instance" "mysql" {
  identifier                  = "needu-${var.environment}-mysql"
  engine                      = "mysql"
  engine_version              = var.mysql_engine_version
  instance_class              = var.mysql_instance_class
  allocated_storage           = var.mysql_storage_gb
  storage_type                = "gp3"
  db_name                     = "needu"
  username                    = "needu"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.main.name
  vpc_security_group_ids      = [aws_security_group.mysql.id]
  publicly_accessible         = false
  storage_encrypted           = true
  multi_az                    = var.multi_az
  backup_retention_period     = var.db_backup_retention_days
  deletion_protection         = var.deletion_protection
  skip_final_snapshot         = !var.deletion_protection
  final_snapshot_identifier   = var.deletion_protection ? "needu-${var.environment}-mysql-final" : null
  apply_immediately           = false
  auto_minor_version_upgrade  = false
}
resource "aws_db_instance" "postgres" {
  identifier                  = "needu-${var.environment}-postgres"
  engine                      = "postgres"
  engine_version              = var.postgres_engine_version
  instance_class              = var.postgres_instance_class
  allocated_storage           = var.postgres_storage_gb
  storage_type                = "gp3"
  db_name                     = "needu"
  username                    = "needu"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.main.name
  vpc_security_group_ids      = [aws_security_group.postgres.id]
  publicly_accessible         = false
  storage_encrypted           = true
  multi_az                    = var.multi_az
  backup_retention_period     = var.db_backup_retention_days
  deletion_protection         = var.deletion_protection
  skip_final_snapshot         = !var.deletion_protection
  final_snapshot_identifier   = var.deletion_protection ? "needu-${var.environment}-postgres-final" : null
  apply_immediately           = false
  auto_minor_version_upgrade  = false
  parameter_group_name        = aws_db_parameter_group.postgres.name
}
resource "aws_db_parameter_group" "postgres" {
  name   = "needu-${var.environment}-postgres-pg"
  family = "postgres${split(".", var.postgres_engine_version)[0]}"
  parameter {
    name         = "rds.logical_replication"
    value        = var.enable_dms ? "1" : "0"
    apply_method = "pending-reboot"
  }
}
resource "aws_elasticache_subnet_group" "redis" {
  name       = "needu-${var.environment}-redis-subnets"
  subnet_ids = local.db_subnet_ids
}
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "needu-${var.environment}-redis"
  description                = "NeedU ${var.environment} Redis"
  engine                     = "redis"
  node_type                  = var.redis_node_type
  port                       = 6379
  num_cache_clusters         = var.environment == "dev" ? 1 : 2
  automatic_failover_enabled = var.environment != "dev"
  multi_az_enabled           = var.environment != "dev"
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.enable_redis_auth ? var.redis_auth_token : null
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis.id]
  snapshot_retention_limit   = var.environment == "dev" ? 0 : 7
  apply_immediately          = false
}
resource "aws_s3_bucket" "catalog" {
  bucket_prefix = "needu-${var.environment}-catalog-"
  force_destroy = var.environment != "prod"
}
resource "aws_s3_bucket_versioning" "catalog" {
  bucket = aws_s3_bucket.catalog.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "catalog" {
  bucket = aws_s3_bucket.catalog.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_s3_bucket_public_access_block" "catalog" {
  bucket                  = aws_s3_bucket.catalog.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
