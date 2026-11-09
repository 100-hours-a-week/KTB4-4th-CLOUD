output "artifact_registry_repository" {
  description = "Artifact Registry repository that stores the vLLM image"
  value       = google_artifact_registry_repository.vllm.name
}

output "artifact_registry_hostname" {
  description = "Regional Docker registry hostname"
  value       = "${var.region}-docker.pkg.dev"
}

output "vertex_runtime_service_account" {
  description = "Runtime service account attached to Vertex vLLM deployment"
  value       = google_service_account.vertex_runtime.email
}

output "vertex_invoker_service_account" {
  description = "GCP service account impersonated by EKS ai-fastapi"
  value       = google_service_account.vertex_invoker.email
}

output "vertex_deployer_service_account" {
  description = "Service account for uploading custom models and deploying them to the Dev endpoint"
  value       = google_service_account.vertex_deployer.email
}

output "workload_identity_provider" {
  description = "Audience used by the EKS external account credential configuration"
  value       = google_iam_workload_identity_pool_provider.eks.name
}

output "workload_identity_token_audience" {
  description = "Audience to set on the projected Kubernetes ServiceAccount token for EKS Workload Identity Federation"
  value       = "https://iam.googleapis.com/${google_iam_workload_identity_pool_provider.eks.name}"
}

output "hf_token_secret_id" {
  description = "Secret Manager secret name only; no secret version is managed by Terraform"
  value       = google_secret_manager_secret.hf_token.secret_id
}

output "vertex_endpoint_name" {
  description = "Vertex endpoint resource name when endpoint creation is enabled"
  value       = try(google_vertex_ai_endpoint.vllm[0].name, null)
}

output "vertex_endpoint_id" {
  description = "Numeric endpoint ID used by the Vertex deployment helper"
  value       = try(google_vertex_ai_endpoint.vllm[0].name, null)
}

output "vertex_dedicated_endpoint_dns" {
  description = "Dedicated endpoint DNS when endpoint creation is enabled"
  value       = try(google_vertex_ai_endpoint.vllm[0].dedicated_endpoint_dns, null)
}
