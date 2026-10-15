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

resource "aws_acm_certificate_validation" "environment" {
  for_each = aws_acm_certificate.environment

  certificate_arn = each.value.arn

  validation_record_fqdns = concat(
    [aws_route53_record.acm_validation[each.key].fqdn],
    each.key == "staging" ? values(aws_route53_record.staging_cutover_acm_validation)[*].fqdn : []
  )
}

# 최초에는 V1을 바라보고, 이후 연결 대상은 Cutover Workflow에서 전환한다.
resource "aws_route53_record" "staging_cutover" {
  zone_id = data.aws_route53_zone.needu.zone_id
  name    = "staging.needu.gift"
  type    = "CNAME"
  ttl     = 60
  records = ["v1.needu.gift"]

  lifecycle {
    # 리허설 중 Workflow가 변경한 V1/V2 연결 대상을 Terraform이 되돌리지 않는다.
    ignore_changes = [records]
  }
}
