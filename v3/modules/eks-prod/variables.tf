variable "name" { type = string }
variable "cluster_version" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "availability_zones" {
  type = list(string)
  validation {
    condition     = length(var.availability_zones) == 3 && length(distinct(var.availability_zones)) == 3
    error_message = "Prod requires exactly three distinct AZs."
  }
}
variable "node_instance_types" { type = list(string) }
variable "system_max_per_az" {
  type    = number
  default = 2
}
variable "app_max_per_az" {
  type    = number
  default = 2
}
variable "public_access_cidrs" { type = list(string) }
variable "cluster_admin_role_arn" { type = string }
