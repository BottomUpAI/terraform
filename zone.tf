# Created by the Route 53 registrar and already delegated. Import it; never
# recreate it: a new zone gets new nameservers and takes the domain offline.
import {
  to = aws_route53_zone.this
  id = local.zone_id
}

resource "aws_route53_zone" "this" {
  name          = local.domain_name
  comment       = "HostedZone created by Route53 Registrar"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}
