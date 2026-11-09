
# V3 Plan Role은 Apply Role과 별도로 생성되어 있다.
# Terraform refresh에 필요한 리소스 조회 권한을 부여한다.
data "aws_iam_policy_document" "v3_plan_eso_read" {
  statement {
    sid       = "DescribeDevPodIdentityAssociations"
    actions   = ["eks:DescribePodIdentityAssociation"]
    resources = ["arn:aws:eks:ap-northeast-2:919551759796:podidentityassociation/needu-v3-dev/*"]
  }

  statement {
    sid     = "DescribeDevRDSInstances"
    actions = ["rds:DescribeDBInstances"]
    resources = [
      "arn:aws:rds:ap-northeast-2:919551759796:db:needu-dev-mysql",
      "arn:aws:rds:ap-northeast-2:919551759796:db:needu-dev-postgres",
    ]
  }

  statement {
    sid       = "ReadExternalSecretsRolePolicy"
    actions   = ["iam:GetRolePolicy", "iam:ListRolePolicies"]
    resources = ["arn:aws:iam::919551759796:role/needu-v3-dev-external-secrets"]
  }

  statement {
    sid     = "ReadDevNodeSchedules"
    actions = ["scheduler:GetSchedule"]
    resources = [
      "arn:aws:scheduler:ap-northeast-2:919551759796:schedule/default/needu-v3-dev-*-night-stop",
      "arn:aws:scheduler:ap-northeast-2:919551759796:schedule/default/needu-v3-dev-*-morning-start",
    ]
  }

  statement {
    sid       = "ListDevNodeScheduleTags"
    actions   = ["scheduler:ListTagsForResource"]
    resources = ["*"]
  }

  # Valkey Streams / Cache Terraform State Refresh
  statement {
    sid = "DescribeDevValkey"

    actions = [
      "elasticache:DescribeReplicationGroups",
      "elasticache:DescribeCacheSubnetGroups",
      "elasticache:DescribeCacheClusters",
      "elasticache:DescribeCacheParameterGroups",
      "elasticache:ListTagsForResource",
    ]

    resources = ["*"]
  }

  statement {
    sid = "ReadDevMonitoringAndAlerting"

    actions = [
      "aps:DescribeLoggingConfiguration",
      "aps:DescribeWorkspace",
      "aps:ListTagsForResource",
      "grafana:DescribeWorkspace",
      "grafana:ListTagsForResource",
      "lambda:GetFunction",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:GetFunctionConcurrency",
      "lambda:GetPolicy",
      "lambda:GetRuntimeManagementConfig",
      "lambda:ListTags",
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "sns:GetSubscriptionAttributes",
      "sns:GetTopicAttributes",
      "sns:ListTagsForResource",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "v3_plan_eso_read" {
  name   = "TerraformV3ESOPlanRead"
  role   = "NeedU-V3-Terraform-Plan"
  policy = data.aws_iam_policy_document.v3_plan_eso_read.json
}
