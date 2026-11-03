variable "name" { type = string }
variable "vpc_id" { type = string }
variable "availability_zones" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
