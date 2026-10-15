locals {
  acm_domains = {
    dev     = "dev.needu.gift"
    staging = "v2.needu.gift"
    prod    = "prod.needu.gift"
  }
}

resource "aws_acm_certificate" "environment" {
  for_each = local.acm_domains

  domain_name = each.value
  subject_alternative_names = each.key == "staging" ? [
    "staging.needu.gift"
  ] : []
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "needu-v2-${each.key}-acm"
    Environment = each.key
    ManagedBy   = "Terraform"
  }
}
