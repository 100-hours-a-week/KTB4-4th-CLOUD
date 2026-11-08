
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

# AMP (Prometheus) 조회 권한
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

# CloudWatch 데이터 소스 탐색 및 메트릭 조회 권한
data "aws_iam_policy_document" "grafana_cloudwatch_read" {
  statement {
    sid    = "DiscoverCloudWatch"
    effect = "Allow"

    actions = [
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:DescribeAlarms",
      "ec2:DescribeRegions",
      "logs:DescribeLogGroups"
    ]

    resources = ["*"]
  }

  # NeedU V3 Dev 애플리케이션 로그 조회 권한
  statement {
    sid    = "ReadDevApplicationLogs"
    effect = "Allow"

    actions = [
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults"
    ]

    resources = [
      "arn:aws:logs:ap-northeast-2:919551759796:log-group:/needu/v3/dev/eks/application",
      "arn:aws:logs:ap-northeast-2:919551759796:log-group:/needu/v3/dev/eks/application:*"
    ]
  }
}

resource "aws_iam_role_policy" "grafana_cloudwatch_read" {
  name   = "ReadNeedUV3DevCloudWatch"
  role   = aws_iam_role.grafana.name
  policy = data.aws_iam_policy_document.grafana_cloudwatch_read.json
}

# Amazon Managed Grafana Workspace
resource "aws_grafana_workspace" "dev" {
  name                     = "${module.eks.cluster_name}-grafana"
  description              = "NeedU V3 Dev EKS monitoring"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "CUSTOMER_MANAGED"
  role_arn                 = aws_iam_role.grafana.arn

  data_sources = [
    "PROMETHEUS",
    "CLOUDWATCH"
  ]

  depends_on = [
    aws_iam_role_policy.grafana_amp_read,
    aws_iam_role_policy.grafana_cloudwatch_read
  ]
}
