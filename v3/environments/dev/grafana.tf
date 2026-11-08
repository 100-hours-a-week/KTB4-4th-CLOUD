data "aws_iam_policy_document" "grafana_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["grafana.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "grafana" {
  name               = "${module.eks.cluster_name}-grafana"
  assume_role_policy = data.aws_iam_policy_document.grafana_assume.json
}

data "aws_iam_policy_document" "grafana_amp_read" {
  statement {
    sid    = "ReadDevAMP"
    effect = "Allow"

    actions = [
      "aps:DescribeWorkspace",
      "aps:QueryMetrics",
      "aps:GetLabels",
      "aps:GetSeries",
      "aps:GetMetricMetadata"
    ]

    resources = [
      aws_prometheus_workspace.dev.arn
    ]
  }
}

resource "aws_iam_role_policy" "grafana_amp_read" {
  name   = "ReadNeedUV3DevAMP"
  role   = aws_iam_role.grafana.name
  policy = data.aws_iam_policy_document.grafana_amp_read.json
}

resource "aws_grafana_workspace" "dev" {
  name                     = "${module.eks.cluster_name}-grafana"
  description              = "NeedU V3 Dev EKS monitoring"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "CUSTOMER_MANAGED"
  role_arn                 = aws_iam_role.grafana.arn

  data_sources = [
    "PROMETHEUS"
  ]

  depends_on = [
    aws_iam_role_policy.grafana_amp_read
  ]
}