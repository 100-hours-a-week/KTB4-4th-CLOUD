
resource "aws_ssm_parameter" "acm_certificate_arn" {
  for_each = local.acm_domains

  name  = "/needu/v2/${each.key}/acm/certificate-arn"
  type  = "String"
  value = aws_acm_certificate_validation.environment[each.key].certificate_arn

  tags = {
    Name        = "needu-v2-${each.key}-acm-certificate-arn"
    Environment = each.key
    ManagedBy   = "Terraform"
  }
}
