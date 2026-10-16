resource "aws_grafana_workspace" "main" {
  name                     = var.workspace_name
  description              = "NeedU V2 integrated monitoring"

  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"

  data_sources = ["CLOUDWATCH"]

  tags = {
    Project     = "NeedU"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }
}