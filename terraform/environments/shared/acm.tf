# V2의 Dev, Staging, Prod와 최종 운영 도메인이 함께 사용할 인증서
resource "aws_acm_certificate" "main" {
  domain_name               = "needu.gift"
  subject_alternative_names = ["*.needu.gift"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name      = "needu-v2-certificate"
    Project   = "needu"
    ManagedBy = "terraform"
  }
}

# Route53에 ACM 소유권 검증용 DNS 레코드를 생성
resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for option in aws_acm_certificate.main.domain_validation_options : option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  }

  allow_overwrite = true
  zone_id         = "Z10258582M6TRCEOCUBUW"
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
}

# DNS 검증이 끝나 인증서가 발급될 때까지 Terraform Apply를 대기
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}

output "certificate_arn" {
  value = aws_acm_certificate_validation.main.certificate_arn
}
