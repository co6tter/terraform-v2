data "aws_route53_zone" "root" {
  name         = var.zone_name # 例: example.com.
  private_zone = false
}

resource "aws_acm_certificate" "cert" {
  provider          = aws.use1
  domain_name       = "*.${local.root_domain}"
  validation_method = "DNS"

  subject_alternative_names = [local.root_domain]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.root.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.value]
  ttl             = 300
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.use1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_route53_record" "cf_alias" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront 固定 Hosted Zone ID
    evaluate_target_health = false
  }
}
