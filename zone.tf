# Created by the Route 53 registrar and already delegated; imported into state
# on 2026-10-24 (see git history for the import block). Never recreate it: a
# new zone gets new nameservers and takes the domain offline.
resource "aws_route53_zone" "this" {
  name          = local.domain_name
  comment       = "HostedZone created by Route53 Registrar"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}
