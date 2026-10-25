locals {
  enable_mysql_secret_rotation_redeploy = contains(["staging", "prod"], var.environment)
}

data "archive_file" "mysql_secret_rotation_redeploy" {
  count = local.enable_mysql_secret_rotation_redeploy ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/lambda/ecs_secret_rotation_redeploy.py"
  output_path = "${path.root}/.terraform/needu-${var.environment}-mysql-secret-rotation-redeploy.zip"
}

data "aws_iam_policy_document" "secret_rotation_lambda_assume" {
  count = local.enable_mysql_secret_rotation_redeploy ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "secret_rotation_redeploy" {
  count = local.enable_mysql_secret_rotation_redeploy ? 1 : 0

  name                 = "needu-${var.environment}-secret-rotation-task"
  assume_role_policy   = data.aws_iam_policy_document.secret_rotation_lambda_assume[0].json
  permissions_boundary = var.iam_runtime_permissions_boundary_arn
}

data "aws_iam_policy_document" "secret_rotation_redeploy" {
  count = local.enable_mysql_secret_rotation_redeploy ? 1 : 0

  statement {
    sid       = "RedeployBackendService"
    actions   = ["ecs:UpdateService"]
    resources = [aws_ecs_service.service["backend"].id]
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
  count = local.enable_mysql_secret_rotation_redeploy ? 1 : 0

  name   = "redeploy-backend-after-secret-rotation"
  role   = aws_iam_role.secret_rotation_redeploy[0].id
  policy = data.aws_iam_policy_document.secret_rotation_redeploy[0].json
}

resource "aws_cloudwatch_log_group" "secret_rotation_redeploy" {
  count = local.enable_mysql_secret_rotation_redeploy ? 1 : 0

  name              = "/needu/${var.environment}/automation/mysql-secret-rotation-redeploy"
  retention_in_days = 30
}

resource "aws_lambda_function" "secret_rotation_redeploy" {
  count = local.enable_mysql_secret_rotation_redeploy ? 1 : 0

  function_name = "needu-${var.environment}-mysql-secret-rotation-redeploy"
  role          = aws_iam_role.secret_rotation_redeploy[0].arn
  handler       = "ecs_secret_rotation_redeploy.handler"
  runtime       = "python3.13"
  timeout       = 30

  filename         = data.archive_file.mysql_secret_rotation_redeploy[0].output_path
  source_code_hash = data.archive_file.mysql_secret_rotation_redeploy[0].output_base64sha256

  environment {
    variables = {
      CLUSTER_NAME        = aws_ecs_cluster.main.name
      SERVICE_NAME        = aws_ecs_service.service["backend"].name
      EXPECTED_SECRET_ARN = aws_db_instance.mysql.master_user_secret[0].secret_arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.secret_rotation_redeploy,
    aws_iam_role_policy.secret_rotation_redeploy
  ]
}

resource "aws_cloudwatch_event_rule" "mysql_secret_rotation" {
  count = local.enable_mysql_secret_rotation_redeploy ? 1 : 0

  name        = "needu-${var.environment}-mysql-secret-rotation"
  description = "Redeploy Backend ECS tasks when the RDS-managed MySQL secret changes"

  event_pattern = jsonencode({
    source      = ["aws.secretsmanager"]
    detail-type = ["Secret Label Updated"]
    resources   = [aws_db_instance.mysql.master_user_secret[0].secret_arn]
    detail = {
      labelUpdated = ["AWSCURRENT"]
    }
  })
}

resource "aws_cloudwatch_event_target" "mysql_secret_rotation_redeploy" {
  count = local.enable_mysql_secret_rotation_redeploy ? 1 : 0

  rule      = aws_cloudwatch_event_rule.mysql_secret_rotation[0].name
  target_id = "RedeployBackendECS"
  arn       = aws_lambda_function.secret_rotation_redeploy[0].arn

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 10
  }
}

resource "aws_lambda_permission" "allow_secret_rotation_event" {
  count = local.enable_mysql_secret_rotation_redeploy ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.secret_rotation_redeploy[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.mysql_secret_rotation[0].arn
}
