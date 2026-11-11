# Subdomains served by GitHub Pages sites on Nathan's personal account. Each
# repo's Pages settings carry the matching custom domain.
#
# The challenge record verifies bottomuplabs.ai for the ndouglas account
# (github.com/settings/pages), so no other account's Pages site can claim one
# of these subdomains (or any other) while it points at GitHub.

locals {
  github_pages_owner = "ndouglas"

  github_pages_subdomains = {
    arena  = "ARENA_materials"
    resume = "resume"
  }

  # From github.com/settings/pages -> bottomuplabs.ai.
  github_pages_challenge = "c29ac8f306593dc2bb22d41e3700ab"
}

resource "aws_route53_record" "github_pages_challenge" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "_github-pages-challenge-${local.github_pages_owner}.${local.domain_name}"
  type    = "TXT"
  ttl     = local.default_ttl
  records = [local.github_pages_challenge]
}

resource "aws_route53_record" "github_pages" {
  for_each = local.github_pages_subdomains

  zone_id = aws_route53_zone.this.zone_id
  name    = "${each.key}.${local.domain_name}"
  type    = "CNAME"
  ttl     = local.default_ttl
  records = ["${local.github_pages_owner}.github.io."]
}
