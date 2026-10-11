
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

  # RDS 관리형 Secret ARN은 환경 이름을 포함하지 않을 수 있다.
  # 해당 Secret의 Environment 태그가 정확히 일치하는 경우에만 허용한다.
  # 실제 RDS 관리형 Secret에 이 태그가 있는지 적용 전에 확인해야 한다.
  statement {
    sid    = "ReadTaggedEnvironmentRDSSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:rds!*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"

      values = [
        each.key
      ]
    }
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
    sid    = "RegisterEnvironmentTaskDefinitions"
    effect = "Allow"

    actions = [
      "ecs:RegisterTaskDefinition"
    ]

    resources = [
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:task-definition/needu-${each.key}-*"
    ]
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
