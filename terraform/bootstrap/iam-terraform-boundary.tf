# ==================================================
# NeedU V2 - Environment Permissions Boundaries
# ==================================================

# terraform_environments는 iam-terraform-apply.tf에서 선언

# --------------------------------------------------
# 1. ECS Runtime Boundary
# --------------------------------------------------

data "aws_iam_policy_document" "runtime_boundary" {
  for_each = local.terraform_environments

  statement {
    sid    = "ECRAuthorization"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ECRImagePull"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:DescribeImages"
    ]

    resources = [
      "arn:aws:ecr:ap-northeast-2:${data.aws_caller_identity.current.account_id}:repository/need-u/*"
    ]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:log-group:/needu/${each.key}/*"
    ]
  }

  # RDS 관리형 Secret 회전 후 Backend Lambda가 최신 Secret을 다시 주입한
  # ECS Task로 Rolling Deployment를 시작할 수 있도록 허용한다.
  statement {
    sid    = "RedeployBackendAfterSecretRotation"
    effect = "Allow"

    actions = [
      "ecs:UpdateService"
    ]

    resources = [
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:service/needu-${each.key}-cluster/needu-${each.key}-backend"
    ]
  }

  dynamic "statement" {
    for_each = each.key == "staging" ? [1] : []

    content {
      sid       = "PublishBackendMetrics"
      effect    = "Allow"
      actions   = ["cloudwatch:PutMetricData"]
      resources = ["*"]

      condition {
        test     = "StringEquals"
        variable = "cloudwatch:namespace"
        values   = ["NeedU/Backend"]
      }
    }
  }

  statement {
    sid    = "ReadEnvironmentParameters"
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]

    resources = [
      "arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:parameter/needu/v2/${each.key}/*"
    ]
  }

  # RDS 관리형 Secret은 ARN이 rds! 접두사로 시작한다.
  # 실제 Execution Role 정책에서 개별 Secret ARN으로 접근을 제한한다.
  statement {
    sid    = "ReadRDSManagedSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:rds!*"
    ]
  }

  statement {
    sid    = "CatalogInputWrite"
    effect = "Allow"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "arn:aws:s3:::needu-${each.key}-catalog-*/jobs/*/input/*"
    ]
  }

  statement {
    sid    = "CatalogOutputRead"
    effect = "Allow"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "arn:aws:s3:::needu-${each.key}-catalog-*/jobs/*/output/*"
    ]
  }
}

resource "aws_iam_policy" "runtime_boundary" {
  for_each = local.terraform_environments

  name        = "NeedU-V2-${each.key}-RuntimePermissionsBoundary"
  description = "Maximum permissions for NeedU V2 ${each.key} ECS runtime roles"

  policy = data.aws_iam_policy_document.runtime_boundary[each.key].json

  tags = {
    Project     = "NeedU"
    Environment = each.key
    ManagedBy   = "Terraform"
  }
}

# --------------------------------------------------
# 2. GitHub ECS CD Boundary
# --------------------------------------------------

data "aws_iam_policy_document" "cd_boundary" {
  for_each = local.terraform_environments

  statement {
    sid    = "DescribeECS"
    effect = "Allow"

    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTasks"
    ]

    resources = ["*"]
  }

  # Terraform 기준 Task Definition ARN 조회
  # GitHub Actions CD에서 SSM Parameter Store를 통해
  # Terraform이 생성한 기준 Revision ARN을 가져온다.
  statement {
    sid    = "ReadBaselineTaskDefinition"
    effect = "Allow"

    actions = [
      "ssm:GetParameter"
    ]

    resources = [
      for service in ["frontend", "backend", "ai"] :
      "arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:parameter/needu/v2/${each.key}/ecs/${service}/base-task-definition-arn"
    ]
  }

  statement {
    sid    = "UpdateEnvironmentServices"
    effect = "Allow"

    actions = [
      "ecs:UpdateService"
    ]

    resources = [
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:service/*/needu-${each.key}-*"
    ]
  }

  statement {
    sid       = "RegisterEnvironmentTaskDefinitions"
    effect    = "Allow"
    actions   = ["ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid     = "TagEnvironmentTaskDefinitions"
    effect  = "Allow"
    actions = ["ecs:TagResource"]

    resources = [
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:task-definition/needu-${each.key}-*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ecs:CreateAction"
      values   = ["RegisterTaskDefinition"]
    }
  }

  statement {
    sid    = "PassEnvironmentTaskRoles"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/needu-${each.key}-*-execution",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/needu-${each.key}-*-task"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }

  statement {
    sid    = "ECRAuthorization"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ECRRead"
    effect = "Allow"

    actions = [
      "ecr:BatchGetImage",
      "ecr:DescribeImages"
    ]

    resources = [
      "arn:aws:ecr:ap-northeast-2:${data.aws_caller_identity.current.account_id}:repository/need-u/*"
    ]
  }
}

resource "aws_iam_policy" "cd_boundary" {
  for_each = local.terraform_environments

  name        = "NeedU-V2-${each.key}-CDPermissionsBoundary"
  description = "Maximum permissions for NeedU V2 ${each.key} GitHub ECS CD role"

  policy = data.aws_iam_policy_document.cd_boundary[each.key].json

  tags = {
    Project     = "NeedU"
    Environment = each.key
    ManagedBy   = "Terraform"
  }
}
