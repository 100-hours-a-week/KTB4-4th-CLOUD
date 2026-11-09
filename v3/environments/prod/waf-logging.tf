resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-needu-v3-prod"
  retention_in_days = 7

  tags = {
    Project     = "NeedU"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "prod" {
  resource_arn            = aws_wafv2_web_acl.prod.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  redacted_fields {
    single_header {
      name = "x-api-key"
    }
  }

  depends_on = [aws_cloudwatch_log_group.waf]
}
