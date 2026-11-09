variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}
variable "name" {
  type    = string
  default = "needu-v3-prod"
}
variable "vpc_id" { type = string }
variable "availability_zones" {
  type = list(string)
  validation {
    condition     = length(var.availability_zones) == 3 && length(distinct(var.availability_zones)) == 3
    error_message = "Prod requires exactly 3 distinct AZs."
  }
}
variable "existing_public_subnet_ids" {
  description = "Existing V2 prod public subnet IDs ordered as AZ a, AZ c"
  type        = list(string)
  validation {
    condition     = length(var.existing_public_subnet_ids) == 2
    error_message = "Provide exactly two existing public subnet IDs."
  }
}
variable "new_public_subnet_cidr" { type = string }
variable "private_subnet_cidrs" {
  type = list(string)
  validation {
    condition     = length(var.private_subnet_cidrs) == 3
    error_message = "Provide exactly three private subnet CIDRs."
  }
}
variable "internet_gateway_id" { type = string }
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
variable "eks_public_access_cidrs" { type = list(string) }
variable "eks_cluster_admin_role_arn" { type = string }
