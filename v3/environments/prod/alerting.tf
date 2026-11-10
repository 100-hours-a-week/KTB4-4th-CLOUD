resource "aws_sns_topic" "prod_alerts" {
  name = "needu-v3-prod-alerts"
}

resource "aws_secretsmanager_secret" "discord_webhook" {
  name                    = "needu/v3/prod/discord-webhook"
  description             = "Discord webhook for NeedU V3 Production alerts; populate out of band"
  recovery_window_in_days = 7
}

data "aws_iam_policy_document" "discord_lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "discord_notifier" {
  name               = "needu-v3-prod-discord-notifier"
  assume_role_policy = data.aws_iam_policy_document.discord_lambda_assume.json
}

resource "aws_cloudwatch_log_group" "discord_notifier" {
  name              = "/aws/lambda/needu-v3-prod-discord-notifier"
  retention_in_days = 30
}

data "aws_iam_policy_document" "discord_notifier" {
  statement {
    sid       = "ReadDiscordWebhook"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.discord_webhook.arn]
  }

  statement {
    sid     = "WriteLambdaLogs"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [
      "${aws_cloudwatch_log_group.discord_notifier.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "discord_notifier" {
  name   = "NeedUV3ProdDiscordNotifier"
  role   = aws_iam_role.discord_notifier.id
  policy = data.aws_iam_policy_document.discord_notifier.json
}

data "archive_file" "discord_notifier" {
  type        = "zip"
  source_file = "${path.module}/lambda/discord_notifier.py"
  output_path = "${path.module}/discord_notifier.zip"
}

resource "aws_lambda_function" "discord_notifier" {
  function_name    = "needu-v3-prod-discord-notifier"
  role             = aws_iam_role.discord_notifier.arn
  runtime          = "python3.12"
  handler          = "discord_notifier.handler"
  filename         = data.archive_file.discord_notifier.output_path
  source_code_hash = data.archive_file.discord_notifier.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      DISCORD_WEBHOOK_SECRET_ARN = aws_secretsmanager_secret.discord_webhook.arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.discord_notifier,
    aws_iam_role_policy.discord_notifier,
  ]
}

resource "aws_lambda_permission" "sns_invoke_discord" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.discord_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.prod_alerts.arn
}

resource "aws_sns_topic_subscription" "discord_notifier" {
  topic_arn = aws_sns_topic.prod_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.discord_notifier.arn

  depends_on = [
    aws_lambda_permission.sns_invoke_discord,
  ]
}

output "prod_alerts_sns_topic_arn" {
  description = "SNS topic ARN for V3 Production alerts"
  value       = aws_sns_topic.prod_alerts.arn
}

output "discord_webhook_secret_arn" {
  description = "Secrets Manager ARN whose value must be populated out of band"
  value       = aws_secretsmanager_secret.discord_webhook.arn
}