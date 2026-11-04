
output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "external_secrets_role_arn" {
  description = "IAM role associated with the external-secrets/external-secrets ServiceAccount"
  value       = aws_iam_role.eso.arn
}

# Valkey Streams - 기존 리소스
output "valkey_stream_primary_endpoint" {
  description = "Valkey Streams primary endpoint"
  value       = module.valkey.primary_endpoint
}

output "valkey_stream_security_group_id" {
  description = "Valkey Streams security group ID"
  value       = module.valkey.security_group_id
}

# Valkey Cache - 신규 리소스
output "valkey_cache_primary_endpoint" {
  description = "Valkey Cache primary endpoint"
  value       = module.valkey_cache.primary_endpoint
}

output "valkey_cache_security_group_id" {
  description = "Valkey Cache security group ID"
  value       = module.valkey_cache.security_group_id
}

# 기존 Output 호환성 유지
output "valkey_primary_endpoint" {
  description = "Legacy output for Valkey Streams primary endpoint"
  value       = module.valkey.primary_endpoint
}

output "valkey_security_group_id" {
  description = "Legacy output for Valkey Streams security group ID"
  value       = module.valkey.security_group_id
}
