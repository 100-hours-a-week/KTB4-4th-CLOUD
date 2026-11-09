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
variable "display_name" {
  description = "Display name for Valkey resources"
  type        = string
}
variable "description" {
  description = "Replication group description. Default preserves existing Dev configuration."
  type        = string
  default     = "NeedU V3 Dev Valkey"
}
variable "num_cache_clusters" {
  description = "Total nodes including primary and replicas."
  type        = number
  default     = 1
  validation {
    condition     = var.num_cache_clusters >= 1
    error_message = "num_cache_clusters must be at least 1."
  }
}
variable "automatic_failover_enabled" {
  type    = bool
  default = false
}
variable "multi_az_enabled" {
  type    = bool
  default = false
}
variable "snapshot_retention_limit" {
  type    = number
  default = 0
}
