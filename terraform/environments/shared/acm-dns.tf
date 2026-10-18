data "aws_route53_zone" "needu" {
  name         = "needu.gift."
  private_zone = false
}

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for env, cert in aws_acm_certificate.environment :
    env => {
      name = one([
        for option in cert.domain_validation_options :
        option.resource_record_name if option.domain_name == cert.domain_name
      ])
      record = one([
        for option in cert.domain_validation_options :
        option.resource_record_value if option.domain_name == cert.domain_name
      ])
      type = one([
        for option in cert.domain_validation_options :
        option.resource_record_type if option.domain_name == cert.domain_name
      ])
    }
  }

  zone_id = data.aws_route53_zone.needu.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.record]

  allow_overwrite = true
}

# Cutover 공통 도메인을 Staging 인증서에 추가로 검증한다.
resource "aws_route53_record" "staging_cutover_acm_validation" {
  # 키를 코드에서 고정해 인증서 발급 전에도 Terraform이 리소스 주소를 계산할 수 있게 한다.
  for_each = { staging = "staging.needu.gift" }

  zone_id = data.aws_route53_zone.needu.zone_id
  name = one([
    for option in aws_acm_certificate.environment["staging"].domain_validation_options :
    option.resource_record_name if option.domain_name == each.value
  ])
  type = one([
    for option in aws_acm_certificate.environment["staging"].domain_validation_options :
    option.resource_record_type if option.domain_name == each.value
  ])
  ttl = 300
  records = [one([
    for option in aws_acm_certificate.environment["staging"].domain_validation_options :
    option.resource_record_value if option.domain_name == each.value
  ])]

  allow_overwrite = true
}

# 최종 운영 도메인 needu.gift를 Prod 공통 ALB에서 사용할 수 있도록 검증합니다.
resource "aws_route53_record" "prod_cutover_acm_validation" {
  for_each = { prod = "needu.gift" }

  zone_id = data.aws_route53_zone.needu.zone_id
  name = one([
    for option in aws_acm_certificate.prod_cutover.domain_validation_options :
    option.resource_record_name if option.domain_name == each.value
  ])
  type = one([
    for option in aws_acm_certificate.prod_cutover.domain_validation_options :
    option.resource_record_type if option.domain_name == each.value
  ])
  ttl = 300
  records = [one([
    for option in aws_acm_certificate.prod_cutover.domain_validation_options :
    option.resource_record_value if option.domain_name == each.value
  ])]

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "environment" {
  for_each = aws_acm_certificate.environment

  certificate_arn = each.value.arn

  validation_record_fqdns = concat(
    [aws_route53_record.acm_validation[each.key].fqdn],
    each.key == "staging" ? values(aws_route53_record.staging_cutover_acm_validation)[*].fqdn : []
  )
}

resource "aws_acm_certificate_validation" "prod_cutover" {
  certificate_arn = aws_acm_certificate.prod_cutover.arn

  # prod.needu.gift의 기존 검증 레코드는 같은 계정에서 재사용할 수 있습니다.
  validation_record_fqdns = [
    aws_route53_record.acm_validation["prod"].fqdn,
    aws_route53_record.prod_cutover_acm_validation["prod"].fqdn
  ]
}

# staging.needu.gift permanently enters through the shared staging ALB.
# V1/V2 switching is handled by ALB listener rules, not DNS updates.
resource "aws_route53_record" "staging_cutover" {
  zone_id = data.aws_route53_zone.needu.zone_id
  name    = "staging.needu.gift"
  type    = "CNAME"
  ttl     = 60
  records = ["v2.needu.gift"]
}
