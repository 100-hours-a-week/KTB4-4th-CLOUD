output "alb_dns_name" {
  value = var.enable_ecs_applications ? aws_lb.main[0].dns_name : var.route53_alias_target.dns_name
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

output "public_route_table_id" {
  description = "Public subnets route table ID"
  value       = aws_route_table.public.id
}

output "db_subnet_ids" {
  value = local.db_subnet_ids
}

output "db_route_table_id" {
  description = "DB 서브넷이 사용하는 Route Table ID"
  value       = aws_route_table.db.id
}

output "alb_security_group_id" {
  description = "Application Load Balancer security group ID"
  value       = var.enable_ecs_applications ? aws_security_group.alb[0].id : null
}

output "https_listener_arn" {
  description = "HTTPS listener ARN"
  value       = var.enable_ecs_applications ? aws_lb_listener.https[0].arn : null
}

output "frontend_target_group_arn" {
  description = "Frontend target group ARN"
  value       = var.enable_ecs_applications ? aws_lb_target_group.fe[0].arn : null
}

output "backend_target_group_arn" {
  description = "Backend target group ARN"
  value       = var.enable_ecs_applications ? aws_lb_target_group.be[0].arn : null
}

output "ecs_security_group_ids" {
  value = var.enable_ecs_applications ? {
    fe = aws_security_group.fe[0].id
    be = aws_security_group.be[0].id
    ai = aws_security_group.ai[0].id
  } : {}
}

output "mysql_address" {
  value = var.enable_databases ? aws_db_instance.mysql[0].address : null
}

output "postgres_address" {
  value = var.enable_databases ? aws_db_instance.postgres[0].address : null
}

output "mysql_secret_arn" {
  value = var.enable_databases ? aws_db_instance.mysql[0].master_user_secret[0].secret_arn : null
}

output "postgres_secret_arn" {
  value = var.enable_databases ? aws_db_instance.postgres[0].master_user_secret[0].secret_arn : null
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
