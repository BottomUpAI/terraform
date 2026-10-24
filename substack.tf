# Substack custom domain. A no-op until Nathan sets up the domain in Substack
# (Settings -> Domain; $50 one time) and Substack shows the CNAME target.

variable "substack_subdomain" {
  description = "Subdomain for the Substack, e.g. \"writing\". null = no record."
  type        = string
  default     = null
}

variable "substack_cname_target" {
  description = "CNAME target Substack provides. null = no record."
  type        = string
  default     = null
}

resource "aws_route53_record" "substack" {
  count = var.substack_subdomain != null && var.substack_cname_target != null ? 1 : 0

  zone_id = aws_route53_zone.this.zone_id
  name    = "${var.substack_subdomain}.${local.domain_name}"
  type    = "CNAME"
  ttl     = local.default_ttl
  records = [var.substack_cname_target]
}
