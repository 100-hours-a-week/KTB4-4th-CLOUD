locals {
  acm_domains = {
    dev     = "dev.needu.gift"
    staging = "v2.needu.gift"
    prod    = "prod.needu.gift"
  }
}

resource "aws_acm_certificate" "environment" {
  for_each = local.acm_domains

  domain_name               = each.value
  subject_alternative_names = each.key == "staging" ? ["staging.needu.gift"] : []
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "needu-v2-${each.key}-acm"
    Environment = each.key
    ManagedBy   = "Terraform"
  }
}

# 기존 Prod 인증서는 ALB가 사용 중이므로 유지하고, 최종 운영 도메인을 포함한 인증서를 별도로 생성합니다.
resource "aws_acm_certificate" "prod_cutover" {
  domain_name               = "prod.needu.gift"
  subject_alternative_names = ["needu.gift"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "needu-v2-prod-cutover-acm"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}
