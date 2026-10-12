data "aws_route53_zone" "needu" {
  name         = "needu.gift."
  private_zone = false
}

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for env, cert in aws_acm_certificate.environment :
    env => {
      name   = tolist(cert.domain_validation_options)[0].resource_record_name
      record = tolist(cert.domain_validation_options)[0].resource_record_value
      type   = tolist(cert.domain_validation_options)[0].resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.needu.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.record]

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "environment" {
  for_each = aws_acm_certificate.environment

  certificate_arn = each.value.arn

  validation_record_fqdns = [
    aws_route53_record.acm_validation[each.key].fqdn
  ]
}