data "google_project" "current" {
  project_id = var.project_id
}

locals {
  labels = {
    project     = "needu"
    version     = "v3"
    environment = var.environment
    managed_by  = "terraform"
  }

  required_services = toset([
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ])

  eks_service_account_subject = "system:serviceaccount:backend:ai-fastapi"
  workload_identity_pool_name = "projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.eks.workload_identity_pool_id}"
  workload_identity_principal = "principal://iam.googleapis.com/${local.workload_identity_pool_name}/subject/${local.eks_service_account_subject}"
}

resource "google_project_service" "required" {
  for_each = local.required_services

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "vllm" {
  project       = var.project_id
  location      = var.region
  repository_id = "needu-vllm"
  description   = "NeedU V3 Dev vLLM inference container images"
  format        = "DOCKER"
  mode          = "STANDARD_REPOSITORY"
  labels        = local.labels

  docker_config {
    immutable_tags = false
  }

  depends_on = [google_project_service.required]
}

resource "google_service_account" "vertex_runtime" {
  project      = var.project_id
  account_id   = "needu-vllm-dev-runtime"
  display_name = "NeedU V3 Dev Vertex vLLM runtime"
  description  = "Runtime identity for the NeedU Dev vLLM custom container"
}

resource "google_service_account" "vertex_invoker" {
  project      = var.project_id
  account_id   = "needu-v3-dev-vertex-invoker"
  display_name = "NeedU V3 Dev EKS Vertex invoker"
  description  = "Impersonated by backend/ai-fastapi through Workload Identity Federation"
}

resource "google_service_account" "vertex_deployer" {
  project      = var.project_id
  account_id   = "needu-v3-dev-vertex-deployer"
  display_name = "NeedU V3 Dev Vertex model deployer"
  description  = "Uploads the custom vLLM model and deploys it to the Dev endpoint"
}

resource "google_project_iam_custom_role" "vertex_model_deployer" {
  project     = var.project_id
  role_id     = "needuVertexModelDeployer"
  title       = "NeedU Vertex Model Deployer"
  description = "Upload vLLM models and deploy them to Vertex endpoints in the dedicated Dev AI project"
  permissions = [
    "aiplatform.endpoints.deploy",
    "aiplatform.endpoints.get",
    "aiplatform.models.get",
    "aiplatform.models.upload",
  ]
}

resource "google_project_iam_member" "vertex_model_deployer" {
  project = var.project_id
  role    = google_project_iam_custom_role.vertex_model_deployer.name
  member  = "serviceAccount:${google_service_account.vertex_deployer.email}"
}

resource "google_service_account_iam_member" "deployer_runtime_act_as" {
  service_account_id = google_service_account.vertex_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.vertex_deployer.email}"
}

resource "google_service_account_iam_member" "vertex_agent_runtime_admin" {
  service_account_id = google_service_account.vertex_runtime.name
  role               = "roles/iam.serviceAccountAdmin"
  member             = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"

  depends_on = [google_project_service.required]
}

resource "google_service_account_iam_member" "operator_deployer_impersonation" {
  count = var.vertex_deployer_operator_member == null ? 0 : 1

  service_account_id = google_service_account.vertex_deployer.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = var.vertex_deployer_operator_member
}

resource "google_project_iam_custom_role" "vertex_endpoint_invoker" {
  project     = var.project_id
  role_id     = "needuVertexEndpointInvoker"
  title       = "NeedU Vertex Endpoint Invoker"
  description = "Invoke NeedU Vertex online prediction endpoints without model administration permissions"
  permissions = ["aiplatform.endpoints.predict"]
}

resource "google_project_iam_member" "vertex_invoker" {
  project = var.project_id
  role    = google_project_iam_custom_role.vertex_endpoint_invoker.name
  member  = "serviceAccount:${google_service_account.vertex_invoker.email}"
}

resource "google_secret_manager_secret" "hf_token" {
  project   = var.project_id
  secret_id = "needu-dev-hf-token"
  labels    = local.labels

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  depends_on = [google_project_service.required]

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_secret_manager_secret_iam_member" "runtime_hf_token" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.hf_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vertex_runtime.email}"
}

resource "google_iam_workload_identity_pool" "eks" {
  project                   = var.project_id
  workload_identity_pool_id = "needu-v3-dev-eks"
  display_name              = "NeedU V3 Dev EKS"
  description               = "Federated identities from the needu-v3-dev EKS cluster"

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "eks" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.eks.workload_identity_pool_id
  workload_identity_pool_provider_id = "needu-v3-dev-eks-oidc"
  display_name                       = "NeedU V3 Dev EKS OIDC"
  description                        = "Trust only the backend/ai-fastapi Kubernetes ServiceAccount"

  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  attribute_condition = "assertion.sub == '${local.eks_service_account_subject}'"

  oidc {
    issuer_uri = var.eks_oidc_issuer_uri
  }
}

resource "google_service_account_iam_member" "eks_impersonation" {
  service_account_id = google_service_account.vertex_invoker.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.workload_identity_principal
}

resource "google_vertex_ai_endpoint" "vllm" {
  count = var.enable_vertex_endpoint ? 1 : 0

  project                    = var.project_id
  location                   = var.region
  region                     = var.region
  name                       = var.vertex_endpoint_id
  display_name               = "needu-v3-dev-vllm"
  description                = "NeedU V3 Dev dedicated vLLM endpoint"
  dedicated_endpoint_enabled = true
  deletion_policy            = "PREVENT"
  labels                     = local.labels

  depends_on = [google_project_service.required]
}
