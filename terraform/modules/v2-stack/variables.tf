
variable "environment" {
  type = string
}

variable "vpc_name" {
  type    = string
  default = "needu-v2-vpc"
}

variable "public_subnets" {
  type = map(object({ az = string, cidr = string }))
}

variable "db_subnets" {
  type = map(object({ az = string, cidr = string }))
}
variable "certificate_arn" {
  type = string
}

variable "hosted_zone_id" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "ecr_repository_urls" {
  type = map(string)
}

variable "image_tags" {
  type = map(string)
}

variable "mysql_engine_version" {
  type = string
}

variable "postgres_engine_version" {
  type = string
}

variable "mysql_instance_class" {
  type = string
}

variable "postgres_instance_class" {
  type = string
}

variable "mysql_storage_gb" {
  type = number
}

variable "postgres_storage_gb" {
  type = number
}

variable "redis_node_type" {
  type = string
}

variable "redis_num_nodes" {
  type    = number
  default = 1

  validation {
    condition     = var.redis_num_nodes >= 1 && floor(var.redis_num_nodes) == var.redis_num_nodes
    error_message = "Redis 노드 수는 1 이상의 정수여야 합니다."
  }
}

variable "task_cpu" {
  type = map(number)
}

variable "task_memory" {
  type = map(number)
}

variable "task_desired_count" {
  type = number
}

variable "autoscaling_min" {
  type = number
}

variable "autoscaling_max" {
  type = number
}

variable "multi_az" {
  type = bool
}

variable "deletion_protection" {
  type = bool
}

variable "db_backup_retention_days" {
  type = number
}

variable "ecs_assign_public_ip" {
  type    = bool
  default = true
}

variable "github_repository" {
  type = string
}

variable "github_oidc_provider_arn" {
  type = string
}

variable "create_dns_record" {
  type    = bool
  default = true
}

variable "enable_redis_auth" {
  type    = bool
  default = false
}

variable "redis_auth_token" {
  type      = string
  sensitive = true
  default   = null
}

variable "enable_alb_access_logs" {
  type    = bool
  default = false
}

variable "alb_logs_bucket" {
  type    = string
  default = ""
}

variable "alarm_sns_topic_arn" {
  type    = string
  default = ""
}

variable "deployment_5xx_threshold" {
  type    = number
  default = 5
}

variable "catalog_commands" {
  type    = map(list(string))
  default = {}
}

variable "app_secret_parameters" {
  description = "AWS의 /needu/v2/{env} 경로에 별도 등록한 값을 ECS에 주입할 서비스별 SSM Parameter 이름과 경로"
  type        = map(map(string))
  default     = {}
}

# ==================================================
# IAM Permissions Boundaries
# ==================================================

variable "iam_runtime_permissions_boundary_arn" {
  description = "Permissions boundary ARN for ECS execution and task roles"
  type        = string
}

variable "iam_cd_permissions_boundary_arn" {
  description = "Permissions boundary ARN for GitHub ECS CD role"
  type        = string
}
