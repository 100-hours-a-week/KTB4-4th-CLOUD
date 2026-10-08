terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  backend "s3" {}
}
provider "aws" {
  region = "ap-northeast-2"
  default_tags {
    tags = { Project = "NeedU", Environment = var.environment, ManagedBy = "Terraform" }
  }
}
module "v2" {
  source                         = "../../modules/v2-stack"
  environment                    = var.environment
  vpc_id                         = var.vpc_id
  igw_id                         = var.igw_id
  public_subnets                 = var.public_subnets
  db_subnets                     = var.db_subnets
  certificate_arn                = var.certificate_arn
  hosted_zone_id                 = var.hosted_zone_id
  domain_name                    = var.domain_name
  ecr_repository_urls            = var.ecr_repository_urls
  image_tags                     = var.image_tags
  mysql_engine_version           = var.mysql_engine_version
  postgres_engine_version        = var.postgres_engine_version
  mysql_instance_class           = var.mysql_instance_class
  postgres_instance_class        = var.postgres_instance_class
  mysql_storage_gb               = var.mysql_storage_gb
  postgres_storage_gb            = var.postgres_storage_gb
  redis_node_type                = var.redis_node_type
  task_cpu                       = var.task_cpu
  task_memory                    = var.task_memory
  task_desired_count             = var.task_desired_count
  autoscaling_min                = var.autoscaling_min
  autoscaling_max                = var.autoscaling_max
  multi_az                       = var.multi_az
  deletion_protection            = var.deletion_protection
  db_backup_retention_days       = var.db_backup_retention_days
  app_env                        = var.app_env
  app_secret_parameters          = var.app_secret_parameters
  parameter_prefix               = var.parameter_prefix
  github_repository              = var.github_repository
  github_oidc_provider_arn       = var.github_oidc_provider_arn
  enable_dms                     = var.enable_dms
  dms_source_mysql_host          = var.dms_source_mysql_host
  dms_source_postgres_host       = var.dms_source_postgres_host
  dms_source_mysql_secret_arn    = var.dms_source_mysql_secret_arn
  dms_source_postgres_secret_arn = var.dms_source_postgres_secret_arn
  dms_endpoint_access_role_arn   = var.dms_endpoint_access_role_arn
  enable_redis_auth              = var.enable_redis_auth
  redis_auth_token               = var.redis_auth_token
  alarm_sns_topic_arn            = var.alarm_sns_topic_arn
}
output "alb_dns_name" {
  value = module.v2.alb_dns_name
}
output "ecs_cluster_name" {
  value = module.v2.ecs_cluster_name
}
output "ecs_services" {
  value = module.v2.ecs_services
}
output "mysql_address" {
  value = module.v2.mysql_address
}
output "postgres_address" {
  value = module.v2.postgres_address
}
output "redis_endpoint" {
  value = module.v2.redis_endpoint
}
output "catalog_bucket" {
  value = module.v2.catalog_bucket
}
output "github_cd_role_arn" {
  value = module.v2.github_cd_role_arn
}
output "batch_task_definition_arns" {
  value = module.v2.batch_task_definition_arns
}
output "github_ci_role_arn" {
  value = module.v2.github_ci_role_arn
}
