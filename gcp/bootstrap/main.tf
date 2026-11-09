resource "google_storage_bucket" "terraform_state" {
  project                     = var.project_id
  name                        = var.state_bucket_name
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  labels = {
    project     = "needu"
    version     = "v3"
    environment = "dev"
    purpose     = "terraform-state"
    managed_by  = "terraform"
  }

  depends_on = [google_project_service.storage]
}

resource "google_project_service" "storage" {
  project            = var.project_id
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}
