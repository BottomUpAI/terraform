# Fastmail, same records as Nathan's other Fastmail domains.

variable "dmarc_policy" {
  description = "DMARC TXT value. Start at p=none; tighten once Fastmail shows DKIM verified."
  type        = string
  default     = "v=DMARC1; p=none; adkim=r; aspf=r"
}

resource "aws_route53_record" "mx" {
  zone_id = aws_route53_zone.this.zone_id
  name    = local.domain_name
  type    = "MX"
  ttl     = local.default_ttl
  records = [
    "10 us1-smtp.messagingengine.com.",
    "20 us2-smtp.messagingengine.com.",
  ]
}

resource "aws_route53_record" "spf" {
  zone_id = aws_route53_zone.this.zone_id
  name    = local.domain_name
  type    = "TXT"
  ttl     = local.default_ttl
  records = ["v=spf1 include:spf.messagingengine.com ?all"]
}

resource "aws_route53_record" "dkim" {
  for_each = toset(["fm1", "fm2", "fm3"])

  zone_id = aws_route53_zone.this.zone_id
  name    = "${each.key}._domainkey.${local.domain_name}"
  type    = "CNAME"
  ttl     = local.default_ttl
  records = ["${each.key}.${local.domain_name}.dkim.fmhosted.com."]
}

resource "aws_route53_record" "dmarc" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "_dmarc.${local.domain_name}"
  type    = "TXT"
  ttl     = local.default_ttl
  records = [var.dmarc_policy]
}
