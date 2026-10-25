# Rules for each repo's default branch: changes land only through pull
# requests whose CI checks pass. Dependabot auto-merge needs these to exist.
# A repo joins this map once it has CI; its value is the check names to require.
locals {
  required_checks = {
    terraform = ["Format", "Test", "Plan / Plan"]
  }

  # GitHub Actions' app ID; pins each required check to Actions as its source.
  github_actions_integration_id = 15368
}

resource "github_repository_ruleset" "main" {
  for_each = local.required_checks

  name        = "main"
  repository  = each.key
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  # Org admins can still merge a pull request whose checks can't pass, e.g.
  # when CI itself has lost access to AWS. They can't push to main directly.
  bypass_actors {
    actor_type = "OrganizationAdmin"
    # GitHub stores no ID for this actor type and the provider reads it back
    # as 0; any other value shows as drift on every plan.
    actor_id    = 0
    bypass_mode = "pull_request"
  }

  rules {
    deletion         = true
    non_fast_forward = true

    # No approvals required: there is one maintainer, and GitHub won't let an
    # author approve their own pull request.
    pull_request {
      required_approving_review_count = 0
    }

    required_status_checks {
      dynamic "required_check" {
        for_each = each.value
        content {
          context        = required_check.value
          integration_id = local.github_actions_integration_id
        }
      }
    }
  }
}
