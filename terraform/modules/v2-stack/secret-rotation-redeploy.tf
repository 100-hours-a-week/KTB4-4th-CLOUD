locals {
  # Dev에서는 PostgreSQL URL 갱신과 AI ECS 재배포만 수행한다.
  enable_secret_rotation_redeploy       = var.enable_databases && contains(["dev", "staging", "prod"], var.environment)
  enable_mysql_secret_rotation_redeploy = var.enable_databases && contains(["staging", "prod"], var.environment)
  secret_rotation_name                  = var.environment == "dev" ? "postgres-secret-rotation" : "mysql-secret-rotation"
}

data "archive_file" "mysql_secret_rotation_redeploy" {
  count = local.enable_secret_rotation_redeploy ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/lambda/ecs_secret_rotation_redeploy.py"
  output_path = "${path.root}/needu-${var.environment}-${local.secret_rotation_name}-redeploy.zip"
}

data "aws_iam_policy_document" "secret_rotation_lambda_assume" {
  count = local.enable_secret_rotation_redeploy ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "secret_rotation_redeploy" {
  count = local.enable_secret_rotation_redeploy ? 1 : 0

  name                 = "needu-${var.environment}-secret-rotation-task"
  assume_role_policy   = data.aws_iam_policy_document.secret_rotation_lambda_assume[0].json
  permissions_boundary = var.iam_runtime_permissions_boundary_arn
}

data "aws_iam_policy_document" "secret_rotation_redeploy" {
  count = local.enable_secret_rotation_redeploy ? 1 : 0

  statement {
    sid     = "RedeployDatabaseConsumers"
    actions = ["ecs:UpdateService"]
    resources = local.enable_mysql_secret_rotation_redeploy ? [
      aws_ecs_service.service["backend"].id,
      aws_ecs_service.service["ai"].id
    ] : [aws_ecs_service.service["ai"].id]
  }

  statement {
    sid       = "ReadPostgresManagedSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.postgres[0].master_user_secret[0].secret_arn]
  }

  statement {
    sid = "SyncAiDatabaseUrlParameter"
    actions = [
      "ssm:GetParameter",
      "ssm:PutParameter"
    ]
    resources = [
      "arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:parameter${local.parameter_base_path}/ai/CATALOG_DATABASE_URL_RO"
    ]
  }

  statement {
    sid = "WriteLambdaLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.secret_rotation_redeploy[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "secret_rotation_redeploy" {
  count = local.enable_secret_rotation_redeploy ? 1 : 0

  # 기존 Policy 이름을 유지해 Terraform Apply 시 불필요한 교체를 방지한다.
  name   = var.environment == "dev" ? "sync-ai-url-after-postgres-rotation" : "redeploy-backend-after-secret-rotation"
  role   = aws_iam_role.secret_rotation_redeploy[0].id
  policy = data.aws_iam_policy_document.secret_rotation_redeploy[0].json
}

resource "aws_cloudwatch_log_group" "secret_rotation_redeploy" {
  count = local.enable_secret_rotation_redeploy ? 1 : 0

  name              = "/needu/${var.environment}/automation/${local.secret_rotation_name}-redeploy"
  retention_in_days = 30
}

resource "aws_lambda_function" "secret_rotation_redeploy" {
  count = local.enable_secret_rotation_redeploy ? 1 : 0

  function_name = "needu-${var.environment}-${local.secret_rotation_name}-redeploy"
  role          = aws_iam_role.secret_rotation_redeploy[0].arn
  handler       = "ecs_secret_rotation_redeploy.handler"
  runtime       = "python3.13"
  timeout       = 30

  filename         = data.archive_file.mysql_secret_rotation_redeploy[0].output_path
  source_code_hash = data.archive_file.mysql_secret_rotation_redeploy[0].output_base64sha256

  environment {
    variables = {
      CLUSTER_NAME              = aws_ecs_cluster.main.name
      BACKEND_SERVICE_NAME      = aws_ecs_service.service["backend"].name
      AI_SERVICE_NAME           = aws_ecs_service.service["ai"].name
      MYSQL_SECRET_ARN          = aws_db_instance.mysql[0].master_user_secret[0].secret_arn
      POSTGRES_SECRET_ARN       = aws_db_instance.postgres[0].master_user_secret[0].secret_arn
      POSTGRES_HOST             = aws_db_instance.postgres[0].address
      POSTGRES_PORT             = tostring(aws_db_instance.postgres[0].port)
      AI_DATABASE_URL_PARAMETER = "${local.parameter_base_path}/ai/CATALOG_DATABASE_URL_RO"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.secret_rotation_redeploy,
    aws_iam_role_policy.secret_rotation_redeploy
  ]
}

resource "aws_cloudwatch_event_rule" "mysql_secret_rotation" {
  count = local.enable_secret_rotation_redeploy ? 1 : 0

  name        = "needu-${var.environment}-${local.secret_rotation_name}"
  description = "Refresh ECS database consumers when an RDS-managed database secret changes"

  event_pattern = jsonencode({
    source      = ["aws.secretsmanager"]
    detail-type = ["Secret Label Updated"]
    resources = local.enable_mysql_secret_rotation_redeploy ? [
      aws_db_instance.mysql[0].master_user_secret[0].secret_arn,
      aws_db_instance.postgres[0].master_user_secret[0].secret_arn
    ] : [aws_db_instance.postgres[0].master_user_secret[0].secret_arn]
    detail = {
      labelUpdated = ["AWSCURRENT"]
    }
  })
}

resource "aws_cloudwatch_event_target" "mysql_secret_rotation_redeploy" {
  count = local.enable_secret_rotation_redeploy ? 1 : 0

  rule      = aws_cloudwatch_event_rule.mysql_secret_rotation[0].name
  target_id = "RedeployBackendECS"
  arn       = aws_lambda_function.secret_rotation_redeploy[0].arn

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 10
  }
}

resource "aws_lambda_permission" "allow_secret_rotation_event" {
  count = local.enable_secret_rotation_redeploy ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.secret_rotation_redeploy[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.mysql_secret_rotation[0].arn
}
