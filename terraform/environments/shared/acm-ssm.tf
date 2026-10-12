# ==================================================
# NeedU V2 - ACM Certificate ARN Parameters
# ==================================================

resource "aws_ssm_parameter" "acm_certificate_arn" {
  for_each = aws_acm_certificate.environment

  name        = "/needu/v2/${each.key}/acm/certificate-arn"
  description = "NeedU V2 ${each.key} ACM certificate ARN"
  type        = "String"
  value       = each.value.arn

  tags = {
    Project     = "NeedU"
    Environment = each.key
    ManagedBy   = "Terraform"
  }
}