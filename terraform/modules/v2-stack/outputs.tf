output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "app_url" {
  value = "https://${var.domain_name}"
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_services" {
  value = { for k, v in aws_ecs_service.service : k => v.name }
}

output "batch_task_definition_arns" {
  value = { for k, v in aws_ecs_task_definition.batch : k => v.arn }
}

output "public_subnet_ids" {
  value = local.public_subnet_ids
}

output "db_subnet_ids" {
  value = local.db_subnet_ids
}

output "db_route_table_id" {
  description = "DB 서브넷이 사용하는 Route Table ID"
  value       = aws_route_table.db.id
}

output "ecs_security_group_ids" {
  value = {
    fe = aws_security_group.fe.id
    be = aws_security_group.be.id
    ai = aws_security_group.ai.id
  }
}

output "mysql_address" {
  value = aws_db_instance.mysql.address
}

output "postgres_address" {
  value = aws_db_instance.postgres.address
}

output "mysql_secret_arn" {
  value = aws_db_instance.mysql.master_user_secret[0].secret_arn
}

output "postgres_secret_arn" {
  value = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

output "redis_endpoint" {
  value = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "catalog_bucket" {
  value = aws_s3_bucket.catalog.id
}

output "github_cd_role_arns" {
  value = { for service, role in aws_iam_role.github_cd : service => role.arn }
}

# ============================================================
# SSM Bastion용 Outputs
# ============================================================

output "vpc_id" {
  description = "VPC ID used by the V2 environment"
  value       = data.aws_vpc.selected.id
}

output "mysql_security_group_id" {
  description = "MySQL RDS Security Group ID"
  value       = aws_security_group.mysql.id
}

output "postgres_security_group_id" {
  description = "PostgreSQL RDS Security Group ID"
  value       = aws_security_group.postgres.id
}
