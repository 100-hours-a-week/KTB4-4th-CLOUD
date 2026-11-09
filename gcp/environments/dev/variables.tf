variable "project_id" {
  description = "Existing GCP project for the NeedU V3 Dev AI environment"
  type        = string
  default     = "needu-v3-dev-ai-514205"
}

variable "region" {
  description = "GCP region for Dev inference resources"
  type        = string
  default     = "asia-northeast3"
}

variable "environment" {
  description = "Deployment environment label"
  type        = string
  default     = "dev"
}

variable "eks_oidc_issuer_uri" {
  description = "OIDC issuer URI of the needu-v3-dev EKS cluster"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^https://oidc\\.eks\\.ap-northeast-2\\.amazonaws\\.com/id/[A-Za-z0-9]+$", var.eks_oidc_issuer_uri))
    error_message = "eks_oidc_issuer_uri must be the HTTPS OIDC issuer URI of the ap-northeast-2 EKS cluster."
  }
}

variable "enable_vertex_endpoint" {
  description = "Create the dedicated Vertex endpoint after the model and deployment design is confirmed"
  type        = bool
  default     = false
}

variable "vertex_endpoint_id" {
  description = "Stable numeric Vertex endpoint ID reserved for the Dev vLLM endpoint"
  type        = string
  default     = "2650000001"

  validation {
    condition     = can(regex("^[1-9][0-9]{0,9}$", var.vertex_endpoint_id))
    error_message = "vertex_endpoint_id must be a numeric value of at most 10 digits with no leading zero."
  }
}

variable "vertex_deployer_operator_member" {
  description = "Optional IAM principal allowed to impersonate the Vertex model deployer service account, for example user:operator@example.com"
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.vertex_deployer_operator_member == null ||
      can(regex("^(user|group|serviceAccount):.+$", var.vertex_deployer_operator_member))
    )
    error_message = "vertex_deployer_operator_member must use a user:, group:, or serviceAccount: IAM principal, or be null."
  }
}
