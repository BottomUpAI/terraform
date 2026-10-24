# Root-module assertions with mocked providers (nothing is created).

mock_provider "aws" {}
mock_provider "github" {}

override_module {
  target = module.repositories
  outputs = {
    repositories = { site = {}, terraform = {} }
  }
}

# modules/static_site has its own tests (static_site.tftest.hcl).
override_module {
  target = module.site
  outputs = {
    bucket_name              = "bottomuplabs.ai"
    bucket_arn               = "arn:aws:s3:::bottomuplabs.ai"
    distribution_id          = "E000000000000"
    distribution_arn         = "arn:aws:cloudfront::123456789012:distribution/E000000000000"
    distribution_domain_name = "d000000000000.cloudfront.net"
  }
}

override_module {
  target = module.organization_basic
  outputs = {
    github_oidc_role = "arn:aws:iam::665449637458:role/BottomUpAI-github-oidc"
  }
}

run "email_records" {
  command = plan

  assert {
    condition     = toset(aws_route53_record.mx.records) == toset(["10 in1-smtp.messagingengine.com.", "20 in2-smtp.messagingengine.com."])
    error_message = "MX must point at Fastmail."
  }

  assert {
    condition     = toset(aws_route53_record.spf.records) == toset(["v=spf1 include:spf.messagingengine.com ?all"])
    error_message = "SPF must include Fastmail."
  }

  assert {
    condition = alltrue([
      for i in [1, 2, 3] :
      aws_route53_record.dkim["fm${i}"].records == toset(["fm${i}.bottomuplabs.ai.dkim.fmhosted.com."])
    ])
    error_message = "fm1-3 DKIM CNAMEs must point at Fastmail."
  }

  assert {
    condition     = aws_route53_record.dmarc.name == "_dmarc.bottomuplabs.ai"
    error_message = "DMARC record must exist."
  }
}

run "substack_off_by_default" {
  command = plan

  assert {
    condition     = length(aws_route53_record.substack) == 0
    error_message = "No Substack record until it's configured."
  }
}

run "substack_on_when_configured" {
  command = plan

  variables {
    substack_subdomain    = "writing"
    substack_cname_target = "target.substack-custom-domains.com."
  }

  assert {
    condition     = aws_route53_record.substack[0].name == "writing.bottomuplabs.ai"
    error_message = "Substack CNAME must use the chosen subdomain."
  }
}

run "site_deploy_variables" {
  command = plan

  assert {
    condition = (
      github_actions_variable.site_bucket.repository == "site" &&
      github_actions_variable.site_bucket.variable_name == "SITE_BUCKET" &&
      github_actions_variable.site_distribution_id.variable_name == "SITE_DISTRIBUTION_ID"
    )
    error_message = "The site repo needs SITE_BUCKET and SITE_DISTRIBUTION_ID."
  }
}
