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
output "ecs_security_group_ids" {
  value = { fe = aws_security_group.fe.id, be = aws_security_group.be.id, ai = aws_security_group.ai.id }
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
output "github_cd_role_arn" {
  value = aws_iam_role.github_cd.arn
}
output "dms_replication_instance_arn" {
  value = var.enable_dms ? aws_dms_replication_instance.main[0].replication_instance_arn : null
}
output "github_ci_role_arn" {
  value = aws_iam_role.github_ci.arn
}
