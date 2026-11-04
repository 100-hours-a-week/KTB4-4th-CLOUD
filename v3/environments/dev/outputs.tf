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
