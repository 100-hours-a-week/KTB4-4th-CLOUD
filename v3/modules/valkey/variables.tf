variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "eks_node_security_group_id" { type = string }
variable "engine_version" {
  type    = string
  default = "8.0"
}
variable "node_type" {
  type    = string
  default = "cache.t4g.small"
}
