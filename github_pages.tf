# Subdomains served by GitHub Pages sites on Nathan's personal account. Each
# repo's Pages settings carry the matching custom domain.
#
# The challenge records verify bottomuplabs.ai for the ndouglas account and the
# BottomUpAI organization (each one's Settings -> Pages), so no other account's
# Pages site can claim one of these subdomains (or any other).

locals {
  github_pages_owner = "ndouglas"

  github_pages_subdomains = {
    arena  = "ARENA_materials"
    resume = "resume"
  }

  # Owner -> code, from that owner's Settings -> Pages -> bottomuplabs.ai.
  github_pages_challenges = {
    ndouglas   = "c29ac8f306593dc2bb22d41e3700ab"
    BottomUpAI = "a74b38ad30be6a1a66203f53ae1112"
  }
}

moved {
  from = aws_route53_record.github_pages_challenge
  to   = aws_route53_record.github_pages_challenge["ndouglas"]
}

resource "aws_route53_record" "github_pages_challenge" {
  for_each = local.github_pages_challenges

  zone_id = aws_route53_zone.this.zone_id
  name    = lower("_github-pages-challenge-${each.key}.${local.domain_name}")
  type    = "TXT"
  ttl     = local.default_ttl
  records = [each.value]
}

resource "aws_route53_record" "github_pages" {
  for_each = local.github_pages_subdomains

  zone_id = aws_route53_zone.this.zone_id
  name    = "${each.key}.${local.domain_name}"
  type    = "CNAME"
  ttl     = local.default_ttl
  records = ["${local.github_pages_owner}.github.io."]
}
