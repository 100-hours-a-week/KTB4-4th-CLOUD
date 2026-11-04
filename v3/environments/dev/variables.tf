variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}
variable "name" {
  type    = string
  default = "needu-v3-dev"
}
variable "vpc_id" { type = string }
variable "availability_zones" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "cluster_version" { type = string }
variable "node_instance_types" {
  type    = list(string)
  default = ["t3.large"]
}
variable "system_max_per_az" {
  type    = number
  default = 2
}
variable "app_max_per_az" {
  type    = number
  default = 2
}
variable "eks_public_access_cidrs" {
  description = "Allowed CIDRs for the EKS public API endpoint"
  type        = list(string)
}
variable "eks_cluster_admin_role_arn" {
  description = "IAM Role ARN for Dev EKS cluster administration"
  type        = string
}

variable "eso_secret_kms_key_arns" {
  description = "Customer-managed KMS key ARNs used by ESO-readable SSM parameters or RDS secrets; leave empty for AWS-managed keys"
  type        = list(string)
  default     = []
}

variable "valkey_subnet_ids" {
  type = list(string)
}

variable "eks_node_security_group_id" {
  type = string
}