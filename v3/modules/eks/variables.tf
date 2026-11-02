variable "name" {
  type = string
}
variable "cluster_version" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "node_instance_types" {
  type = list(string)
}
variable "system_desired" {
  type = number
}
variable "app_desired" {
  type = number
}
