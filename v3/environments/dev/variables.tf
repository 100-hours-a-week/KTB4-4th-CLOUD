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
variable "system_desired" {
  type    = number
  default = 2
}
variable "app_desired" {
  type    = number
  default = 2
}
