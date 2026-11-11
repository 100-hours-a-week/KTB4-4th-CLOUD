output "vpc_id" { value = data.aws_vpc.existing.id }
output "public_subnet_ids" { value = [data.aws_subnet.public_a.id, aws_subnet.public_b.id, data.aws_subnet.public_c.id] }
output "private_subnet_ids" { value = [for az in var.availability_zones : aws_subnet.private[az].id] }
output "regional_nat_gateway_id" { value = aws_nat_gateway.regional.id }
output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_autoscaler_role_arn" {
  description = "IAM role associated with the kube-system/cluster-autoscaler ServiceAccount"
  value       = aws_iam_role.cluster_autoscaler.arn
}
output "waf_web_acl_arn" {
  description = "V3 Production WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.prod.arn
}

output "amp_workspace_id" {
  description = "NeedU V3 Production AMP Workspace ID"
  value       = aws_prometheus_workspace.prod.id
}

output "amp_workspace_arn" {
  description = "NeedU V3 Production AMP Workspace ARN"
  value       = aws_prometheus_workspace.prod.arn
}

output "amp_remote_write_endpoint" {
  description = "AMP Remote Write endpoint for the Production ADOT Collector"
  value       = "${trimsuffix(aws_prometheus_workspace.prod.prometheus_endpoint, "/")}/api/v1/remote_write"
}

output "adot_role_arn" {
  description = "IAM role associated with the monitoring/adot-collector ServiceAccount"
  value       = aws_iam_role.adot.arn
}

output "fluent_bit_role_arn" {
  description = "IAM role associated with the monitoring/fluent-bit ServiceAccount"
  value       = aws_iam_role.fluent_bit.arn
}

output "application_log_group_name" {
  description = "CloudWatch Log Group for V3 Production EKS application logs"
  value       = aws_cloudwatch_log_group.fluent_bit.name
}

output "grafana_workspace_id" {
  description = "V3 Production Grafana Workspace ID"
  value       = aws_grafana_workspace.prod.id
}

output "grafana_workspace_endpoint" {
  description = "V3 Production Grafana Workspace URL"
  value       = aws_grafana_workspace.prod.endpoint
}

output "grafana_workspace_role_arn" {
  description = "V3 Production Grafana IAM Role ARN"
  value       = aws_iam_role.grafana.arn
}
