
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project     = "NeedU"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Shared Terraform에서 관리하는 Staging ACM 인증서 ARN 조회
data "aws_ssm_parameter" "certificate_arn" {
  name = "/needu/v2/staging/acm/certificate-arn"
}

module "v2" {
  source = "../../modules/v2-stack"

  environment              = var.environment
  public_subnets           = var.public_subnets
  db_subnets               = var.db_subnets
  certificate_arn          = data.aws_ssm_parameter.certificate_arn.value
  hosted_zone_id           = var.hosted_zone_id
  domain_name              = var.domain_name
  ecr_repository_urls      = var.ecr_repository_urls
  image_tags               = var.image_tags
  mysql_engine_version     = var.mysql_engine_version
  postgres_engine_version  = var.postgres_engine_version
  mysql_instance_class     = var.mysql_instance_class
  postgres_instance_class  = var.postgres_instance_class
  mysql_storage_gb         = var.mysql_storage_gb
  postgres_storage_gb      = var.postgres_storage_gb
  redis_node_type          = var.redis_node_type
  redis_num_nodes          = var.redis_num_nodes
  task_cpu                 = var.task_cpu
  task_memory              = var.task_memory
  task_desired_count       = var.task_desired_count
  autoscaling_min          = var.autoscaling_min
  autoscaling_max          = var.autoscaling_max
  multi_az                 = var.multi_az
  deletion_protection      = var.deletion_protection
  db_backup_retention_days = var.db_backup_retention_days
  app_secret_parameters    = var.app_secret_parameters
  github_repositories      = var.github_repositories
  github_oidc_provider_arn = var.github_oidc_provider_arn
  enable_redis_auth        = var.enable_redis_auth
  redis_auth_token         = var.redis_auth_token
  alarm_sns_topic_arn      = var.alarm_sns_topic_arn
  deployment_5xx_threshold = var.deployment_5xx_threshold
  catalog_commands         = var.catalog_commands

  # Staging - ECS Runtime Permissions Boundary
  iam_runtime_permissions_boundary_arn = "arn:aws:iam::919551759796:policy/NeedU-V2-staging-RuntimePermissionsBoundary"

  # Staging - GitHub ECS CD Permissions Boundary
  iam_cd_permissions_boundary_arn = "arn:aws:iam::919551759796:policy/NeedU-V2-staging-CDPermissionsBoundary"
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

output "github_cd_role_arns" {
  value = module.v2.github_cd_role_arns
}

output "batch_task_definition_arns" {
  value = module.v2.batch_task_definition_arns
}
