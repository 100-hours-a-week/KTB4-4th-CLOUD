# --------------------------------------------------
# Grafana Workspace IAM Role
# --------------------------------------------------

data "aws_iam_policy_document" "grafana_assume_role" {
  statement {
    sid     = "GrafanaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["grafana.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "grafana_workspace" {
  name               = "needu-v2-grafana-workspace"
  assume_role_policy = data.aws_iam_policy_document.grafana_assume_role.json

  tags = {
    Project     = "NeedU"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }
}

# --------------------------------------------------
# Grafana CloudWatch Access
# --------------------------------------------------

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  role       = aws_iam_role.grafana_workspace.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonGrafanaCloudWatchAccess"
}

# --------------------------------------------------
# Amazon Managed Grafana Workspace
# --------------------------------------------------

resource "aws_grafana_workspace" "main" {
  name        = var.workspace_name
  description = "NeedU V2 integrated monitoring"

  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "CUSTOMER_MANAGED"

  role_arn     = aws_iam_role.grafana_workspace.arn
  data_sources = ["CLOUDWATCH"]

  tags = {
    Project     = "NeedU"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_iam_role_policy_attachment.grafana_cloudwatch
  ]
}