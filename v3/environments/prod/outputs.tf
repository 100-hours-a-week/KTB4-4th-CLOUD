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
