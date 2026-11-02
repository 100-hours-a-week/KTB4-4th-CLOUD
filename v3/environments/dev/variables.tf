variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}
variable "name" {
  type    = string
  default = "needu-v3-dev"
}
variable "vpc_cidr" {
  type = string
}
variable "availability_zones" {
  type = list(string)
  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Dev requires exactly 2 AZs."
  }
}
variable "public_subnet_cidrs" {
  type = list(string)
  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Provide 2 public subnets."
  }
}
variable "private_subnet_cidrs" {
  type = list(string)
  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Provide 2 private subnets."
  }
}
variable "cluster_version" {
  type = string
}
variable "node_instance_types" {
  type    = list(string)
  default = ["t3.large"]
}
variable "system_desired" {
  type    = number
  default = 2
}
variable "app_desired" {
  type    = number
  default = 2
}
