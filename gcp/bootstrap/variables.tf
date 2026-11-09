variable "project_id" {
  description = "Existing GCP project that owns the Terraform state bucket"
  type        = string
  default     = "needu-v3-dev-ai-514205"
}

variable "region" {
  description = "Region used for the Dev Terraform state bucket"
  type        = string
  default     = "asia-northeast3"
}

variable "state_bucket_name" {
  description = "Globally unique GCS bucket name for GCP Terraform state"
  type        = string
  default     = "needu-v3-dev-ai-514205-tfstate"
}
