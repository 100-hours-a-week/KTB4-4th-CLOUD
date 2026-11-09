variable "name" { type = string }
variable "vpc_id" { type = string }
variable "availability_zones" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "enable_multi_az_nat" {
  description = "Create an independent NAT Gateway and route table for each additional AZ"
  type        = bool
  default     = false
}