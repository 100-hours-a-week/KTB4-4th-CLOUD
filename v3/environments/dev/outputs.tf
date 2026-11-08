
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

output "cluster_autoscaler_role_arn" {
  description = "IAM role associated with the kube-system/cluster-autoscaler ServiceAccount"
  value       = aws_iam_role.cluster_autoscaler.arn
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

# AMP Workspace - V3 Dev 모니터링
output "amp_workspace_id" {
  description = "NeedU V3 Dev AMP Workspace ID"
  value       = aws_prometheus_workspace.dev.id
}

output "amp_workspace_arn" {
  description = "NeedU V3 Dev AMP Workspace ARN"
  value       = aws_prometheus_workspace.dev.arn
}

output "amp_remote_write_endpoint" {
  description = "AMP Remote Write endpoint for ADOT Collector"
  value       = "${trimsuffix(aws_prometheus_workspace.dev.prometheus_endpoint, "/")}/api/v1/remote_write"
}

# ADOT Collector - EKS Pod Identity
output "adot_role_arn" {
  description = "IAM Role ARN for ADOT Collector Pod Identity"
  value       = aws_iam_role.adot.arn
}

output "grafana_workspace_id" {
  description = "V3 Dev Grafana Workspace ID"
  value       = aws_grafana_workspace.dev.id
}

output "grafana_workspace_endpoint" {
  description = "V3 Dev Grafana Workspace URL"
  value       = aws_grafana_workspace.dev.endpoint
}

output "grafana_workspace_role_arn" {
  description = "V3 Dev Grafana IAM Role ARN"
  value       = aws_iam_role.grafana.arn
}