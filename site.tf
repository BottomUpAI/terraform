locals {
  # No third-party origins. wasm-unsafe-eval: WASM simulations. blob: workers.
  content_security_policy = join("; ", [
    "default-src 'self'",
    "script-src 'self' 'wasm-unsafe-eval'",
    "connect-src 'self'",
    "img-src 'self' data:",
    "style-src 'self' 'unsafe-inline'",
    "font-src 'self'",
    "worker-src 'self' blob:",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'none'",
    "frame-ancestors 'none'",
    "upgrade-insecure-requests",
  ])
}

module "site" {
  source = "./modules/static_site"

  domain_name             = local.domain_name
  zone_id                 = aws_route53_zone.this.zone_id
  content_security_policy = local.content_security_policy
}
