
# ==================================================
# NeedU V2 - ECS Runtime IAM
# ==================================================

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

locals {
  parameter_base_path = "/needu/v2/${var.environment}"

  execution_roles = {
    frontend = {
      parameter_path = "${local.parameter_base_path}/frontend-runtime/*"
      secret_arns    = []
    }

    backend = {
      parameter_path = "${local.parameter_base_path}/backend/*"
      secret_arns = [
        aws_db_instance.mysql.master_user_secret[0].secret_arn
      ]
    }

    ai = {
      parameter_path = "${local.parameter_base_path}/ai/*"
      secret_arns    = []
    }

    catalog-sync = {
      parameter_path = "${local.parameter_base_path}/ai-catalog/*"
      secret_arns = [
        aws_db_instance.mysql.master_user_secret[0].secret_arn
      ]
    }

    catalog-import = {
      parameter_path = "${local.parameter_base_path}/ai-catalog/*"
      secret_arns    = []
    }
  }
}

# --------------------------------------------------
# ECS Execution Roles
# --------------------------------------------------

resource "aws_iam_role" "service_execution" {
  for_each = local.execution_roles

  name                 = "needu-${var.environment}-${each.key}-execution"
  assume_role_policy   = data.aws_iam_policy_document.ecs_assume.json
  permissions_boundary = var.iam_runtime_permissions_boundary_arn
}

resource "aws_iam_role_policy_attachment" "service_execution" {
  for_each = local.execution_roles

  role       = aws_iam_role.service_execution[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "service_execution_parameters" {
  for_each = local.execution_roles

  name = "needu-${var.environment}-${each.key}-parameters"
  role = aws_iam_role.service_execution[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = concat(
      [
        {
          Effect = "Allow"

          Action = [
            "ssm:GetParameter",
            "ssm:GetParameters"
          ]

          Resource = [
            "arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:parameter${each.value.parameter_path}"
          ]
        }
      ],
      length(each.value.secret_arns) == 0 ? [] : [
        {
          Effect = "Allow"

          Action = [
            "secretsmanager:GetSecretValue"
          ]

          Resource = each.value.secret_arns
        }
      ]
    )
  })
}

# --------------------------------------------------
# Application Task Roles
# --------------------------------------------------

resource "aws_iam_role" "task" {
  for_each = toset([
    "frontend",
    "backend",
    "ai"
  ])

  name                 = "needu-${var.environment}-${each.key}-task"
  assume_role_policy   = data.aws_iam_policy_document.ecs_assume.json
  permissions_boundary = var.iam_runtime_permissions_boundary_arn
}

data "aws_iam_policy_document" "backend_cloudwatch_metrics" {
  count = var.enable_backend_cloudwatch_metrics ? 1 : 0

  statement {
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

resource "aws_iam_role_policy" "backend_cloudwatch_metrics" {
  count = var.enable_backend_cloudwatch_metrics ? 1 : 0

  name   = "publish-backend-cloudwatch-metrics"
  role   = aws_iam_role.task["backend"].id
  policy = data.aws_iam_policy_document.backend_cloudwatch_metrics[0].json
}

# --------------------------------------------------
# Catalog Task Roles
# --------------------------------------------------

resource "aws_iam_role" "catalog_task" {
  for_each = toset([
    "catalog-sync",
    "catalog-import"
  ])

  name                 = "needu-${var.environment}-${each.key}-task"
  assume_role_policy   = data.aws_iam_policy_document.ecs_assume.json
  permissions_boundary = var.iam_runtime_permissions_boundary_arn
}

resource "aws_iam_role_policy" "catalog_sync" {
  name = "catalog-input-write"
  role = aws_iam_role.catalog_task["catalog-sync"].id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = [
          "${aws_s3_bucket.catalog.arn}/jobs/*/input/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "catalog_import" {
  name = "catalog-output-read"
  role = aws_iam_role.catalog_task["catalog-import"].id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = [
          "${aws_s3_bucket.catalog.arn}/jobs/*/output/*"
        ]
      }
    ]
  })
}
