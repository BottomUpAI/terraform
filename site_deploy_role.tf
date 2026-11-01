# The role BottomUpAI/site's deploy workflow assumes: it can replace the site's
# files and invalidate its distribution, and nothing else. Trusted only for the
# site repo's main branch, by exact match. The org's AdministratorAccess role
# (organization_basic) is not reachable from the site repo.
locals {
  github_oidc_provider_arn = "arn:aws:iam::665449637458:oidc-provider/token.actions.githubusercontent.com"
  site_deploy_subject      = "repo:BottomUpAI@345462692/site@1432185918:ref:refs/heads/main"
}

resource "aws_iam_role" "site_deploy" {
  name        = "BottomUpAI-site-deploy"
  description = "Deploys bottomuplabs.ai from BottomUpAI/site (main only)."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = local.github_oidc_provider_arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = local.site_deploy_subject
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "site_deploy" {
  name = "deploy"
  role = aws_iam_role.site_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = module.site.bucket_arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = "${module.site.bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
        Resource = module.site.distribution_arn
      },
    ]
  })
}
