output "state_bucket_name" {
  description = "GCS bucket used by the GCP Dev root module"
  value       = google_storage_bucket.terraform_state.name
}
