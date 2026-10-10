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
variable "app_env" {
  type    = map(map(string))
  default = {}
}
variable "parameter_prefix" {
  type = string
}
variable "github_repository" {
  type = string
}
variable "github_oidc_provider_arn" {
  type = string
}
variable "enable_dms" {
  type    = bool
  default = false
}
variable "v1_staging_sg_id" {
  type    = string
  default = ""
}
variable "dms_replication_instance_class" {
  type    = string
  default = "dms.t3.medium"
}
variable "dms_source_mysql_host" {
  type    = string
  default = ""
}
variable "dms_source_postgres_host" {
  type    = string
  default = ""
}
variable "dms_source_mysql_port" {
  type    = number
  default = 3306
}
variable "dms_source_postgres_port" {
  type    = number
  default = 5432
}
variable "dms_source_mysql_secret_arn" {
  type    = string
  default = ""
}
variable "dms_source_postgres_secret_arn" {
  type    = string
  default = ""
}
variable "dms_vpc_role_arn" {
  type    = string
  default = ""
}
variable "dms_cloudwatch_role_arn" {
  type    = string
  default = ""
}
variable "dms_endpoint_access_role_arn" {
  type    = string
  default = ""
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

variable "app_secret_parameters" {
  type    = map(map(string))
  default = {}
}
