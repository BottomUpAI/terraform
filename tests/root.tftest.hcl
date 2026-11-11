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
    condition     = toset(aws_route53_record.mx.records) == toset(["10 us1-smtp.messagingengine.com.", "20 us2-smtp.messagingengine.com."])
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

  assert {
    condition     = one(aws_route53_record.dmarc.records) == "v=DMARC1; p=quarantine; rua=mailto:dmarc@bottomuplabs.ai; adkim=r; aspf=r"
    error_message = "DMARC must quarantine failing mail and send aggregate reports to dmarc@."
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

run "main_branch_rules" {
  command = plan

  assert {
    condition     = contains(keys(github_repository_ruleset.main), "terraform")
    error_message = "The terraform repo must have branch rules."
  }

  assert {
    condition = (
      github_repository_ruleset.main["terraform"].enforcement == "active" &&
      github_repository_ruleset.main["terraform"].conditions[0].ref_name[0].include == tolist(["~DEFAULT_BRANCH"])
    )
    error_message = "Rules must be enforced on the default branch."
  }

  assert {
    condition = toset([
      for c in github_repository_ruleset.main["terraform"].rules[0].required_status_checks[0].required_check : c.context
    ]) == toset(["Format", "Test", "Plan / Plan"])
    error_message = "main must require the Format, Test and Plan checks."
  }

  assert {
    condition = alltrue([
      for c in github_repository_ruleset.main["terraform"].rules[0].required_status_checks[0].required_check :
      c.integration_id == 15368
    ])
    error_message = "Required checks must come from GitHub Actions, so nothing else can satisfy them."
  }

  assert {
    condition = (
      github_repository_ruleset.main["terraform"].rules[0].deletion &&
      github_repository_ruleset.main["terraform"].rules[0].non_fast_forward &&
      length(github_repository_ruleset.main["terraform"].rules[0].pull_request) == 1
    )
    error_message = "main must be undeletable, never force-pushed, and changed only through pull requests."
  }

  assert {
    condition = (
      length(github_repository_ruleset.main["terraform"].bypass_actors) == 1 &&
      github_repository_ruleset.main["terraform"].bypass_actors[0].actor_type == "OrganizationAdmin" &&
      github_repository_ruleset.main["terraform"].bypass_actors[0].bypass_mode == "pull_request"
    )
    error_message = "Only org admins may bypass, and only by merging a pull request."
  }
}

run "site_deploy_role" {
  command = plan

  assert {
    condition = (
      one(jsondecode(aws_iam_role.site_deploy.assume_role_policy).Statement).Principal.Federated ==
      "arn:aws:iam::665449637458:oidc-provider/token.actions.githubusercontent.com"
    )
    error_message = "Only the GitHub OIDC provider may assume the site deploy role."
  }

  assert {
    condition = (
      one(jsondecode(aws_iam_role.site_deploy.assume_role_policy).Statement).Condition ==
      {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:BottomUpAI@345462692/site@1432185918:ref:refs/heads/main"
        }
      }
    )
    error_message = "The site deploy role must trust exactly BottomUpAI/site on main, by exact match."
  }

  assert {
    condition = toset([
      for s in jsondecode(aws_iam_role_policy.site_deploy.policy).Statement : jsonencode([sort(s.Action), s.Resource])
      ]) == toset([
      jsonencode([["s3:ListBucket"], "arn:aws:s3:::bottomuplabs.ai"]),
      jsonencode([["s3:DeleteObject", "s3:PutObject"], "arn:aws:s3:::bottomuplabs.ai/*"]),
      jsonencode([["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"], "arn:aws:cloudfront::123456789012:distribution/E000000000000"]),
    ])
    error_message = "The site deploy role may only list/put/delete in the site bucket and invalidate its distribution."
  }

  assert {
    condition     = github_actions_variable.site_deploy_role.repository == "site"
    error_message = "SITE_DEPLOY_ROLE goes to the site repo."
  }

  assert {
    condition = (
      toset(keys(github_repository_ruleset.main)) == toset(["site", "terraform"]) &&
      toset([
        for c in github_repository_ruleset.main["site"].rules[0].required_status_checks[0].required_check : c.context
      ]) == toset(["Static checks", "Browser tests", "Lighthouse"])
    )
    error_message = "site's main must require Static checks, Browser tests and Lighthouse."
  }
}

run "github_pages_subdomains" {
  command = plan

  assert {
    condition     = toset(keys(aws_route53_record.github_pages)) == toset(["arena", "resume"])
    error_message = "Expected CNAMEs for arena and resume."
  }

  assert {
    condition     = aws_route53_record.github_pages["arena"].name == "arena.bottomuplabs.ai" && tolist(aws_route53_record.github_pages["arena"].records) == tolist(["ndouglas.github.io."])
    error_message = "arena must CNAME to ndouglas.github.io."
  }

  assert {
    condition     = aws_route53_record.github_pages_challenge["ndouglas"].name == "_github-pages-challenge-ndouglas.bottomuplabs.ai" && aws_route53_record.github_pages_challenge["BottomUpAI"].name == "_github-pages-challenge-bottomupai.bottomuplabs.ai"
    error_message = "GitHub Pages verification TXT records must exist for ndouglas and BottomUpAI."
  }
}
