resource "aws_route53_record" "acm_validation" {
  for_each = {
    for o in aws_acm_certificate.this.domain_validation_options : o.domain_name => {
      name   = o.resource_record_name
      record = o.resource_record_value
      type   = o.resource_record_type
    }
  }

  allow_overwrite = true
  zone_id         = var.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
}

locals {
  alias_records = {
    "apex-A"    = { name = var.domain_name, type = "A" }
    "apex-AAAA" = { name = var.domain_name, type = "AAAA" }
    "www-A"     = { name = "www.${var.domain_name}", type = "A" }
    "www-AAAA"  = { name = "www.${var.domain_name}", type = "AAAA" }
  }
}

resource "aws_route53_record" "alias" {
  for_each = local.alias_records

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
