# ==================================================
# NeedU V2 - GitHub ECS CD IAM
# ==================================================

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "github_assume" {
  for_each = var.github_repositories

  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        var.github_oidc_provider_arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${each.value}:environment:${var.environment}"
      ]
    }
  }
}

# --------------------------------------------------
# GitHub ECS CD Role
# --------------------------------------------------

resource "aws_iam_role" "github_cd" {
  for_each = var.github_repositories

  name = "needu-${var.environment}-${each.key}-github-ecs-cd"

  assume_role_policy   = data.aws_iam_policy_document.github_assume[each.key].json
  permissions_boundary = var.iam_cd_permissions_boundary_arn
}

# --------------------------------------------------
# ECS Deployment Policy
# --------------------------------------------------

resource "aws_iam_role_policy" "github_cd" {
  for_each = var.github_repositories

  name = "ecs-deploy"
  role = aws_iam_role.github_cd[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "DescribeECS"
        Effect = "Allow"

        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks"
        ]

        Resource = "*"
      },
      {
        Sid    = "ReadBaselineTaskDefinition"
        Effect = "Allow"

        Action = [
          "ssm:GetParameter"
        ]

        Resource = "arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:parameter/needu/v2/${var.environment}/ecs/${each.key}/base-task-definition-arn"
      },
      {
        Sid    = "UpdateEnvironmentServices"
        Effect = "Allow"

        Action = [
          "ecs:UpdateService"
        ]

        Resource = "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:service/*/needu-${var.environment}-${each.key}"
      },
      {
        Sid      = "RegisterTaskDefinitions"
        Effect   = "Allow"
        Action   = ["ecs:RegisterTaskDefinition"]
        Resource = "*"
      },
      {
        Sid    = "TagTaskDefinitions"
        Effect = "Allow"

        Action = [
          "ecs:TagResource"
        ]

        Resource = "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:task-definition/needu-${var.environment}-${each.key}:*"

        Condition = {
          StringEquals = {
            "ecs:CreateAction" = "RegisterTaskDefinition"
          }
        }
      },
      {
        Sid    = "PassEnvironmentRoles"
        Effect = "Allow"

        Action = [
          "iam:PassRole"
        ]

        Resource = [
          aws_iam_role.service_execution[each.key].arn,
          aws_iam_role.task[each.key].arn
        ]

        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      },
      {
        Sid    = "ECRRead"
        Effect = "Allow"

        Action = [
          "ecr:BatchGetImage",
          "ecr:DescribeImages"
        ]

        Resource = "arn:aws:ecr:ap-northeast-2:${data.aws_caller_identity.current.account_id}:repository/need-u/${each.key}"
      },
      {
        Sid    = "ECRAuthorization"
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      }
    ]
  })
}
