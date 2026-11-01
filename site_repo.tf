# Where BottomUpAI/site deploys to. Its OIDC role and GitHub App variables come
# from organization_basic.
resource "github_actions_variable" "site_bucket" {
  repository    = "site"
  variable_name = "SITE_BUCKET"
  value         = module.site.bucket_name
}

resource "github_actions_variable" "site_distribution_id" {
  repository    = "site"
  variable_name = "SITE_DISTRIBUTION_ID"
  value         = module.site.distribution_id
}

resource "github_actions_variable" "site_deploy_role" {
  repository    = "site"
  variable_name = "SITE_DEPLOY_ROLE"
  value         = aws_iam_role.site_deploy.arn
}
