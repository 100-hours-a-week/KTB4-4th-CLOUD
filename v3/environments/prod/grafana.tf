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
    sid    = "ReadProdAMP"
    effect = "Allow"

    actions = [
      "aps:DescribeWorkspace",
      "aps:QueryMetrics",
      "aps:GetLabels",
      "aps:GetSeries",
      "aps:GetMetricMetadata",
    ]

    resources = [aws_prometheus_workspace.prod.arn]
  }
}

resource "aws_iam_role_policy" "grafana_amp_read" {
  name   = "ReadNeedUV3ProdAMP"
  role   = aws_iam_role.grafana.name
  policy = data.aws_iam_policy_document.grafana_amp_read.json
}

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
      "logs:DescribeLogGroups",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ReadProdApplicationLogs"
    effect = "Allow"

    actions = [
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults",
    ]

    resources = [
      aws_cloudwatch_log_group.fluent_bit.arn,
      "${aws_cloudwatch_log_group.fluent_bit.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "grafana_cloudwatch_read" {
  name   = "ReadNeedUV3ProdCloudWatch"
  role   = aws_iam_role.grafana.name
  policy = data.aws_iam_policy_document.grafana_cloudwatch_read.json
}

resource "aws_grafana_workspace" "prod" {
  name                     = "${module.eks.cluster_name}-grafana"
  description              = "NeedU V3 Production EKS monitoring"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "CUSTOMER_MANAGED"
  role_arn                 = aws_iam_role.grafana.arn

  data_sources = [
    "PROMETHEUS",
    "CLOUDWATCH",
  ]

  depends_on = [
    aws_iam_role_policy.grafana_amp_read,
    aws_iam_role_policy.grafana_cloudwatch_read,
  ]
}
