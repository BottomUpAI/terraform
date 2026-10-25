module "repositories" {
  source = "github.com/bitterbridge/terraform-modules//terraform/modules/repositories?ref=v0.0.780"

  organization_name = "BottomUpAI"
}

module "organization_basic" {
  source = "github.com/bitterbridge/terraform-modules//terraform/modules/organization_basic?ref=v0.0.780"

  organization_name  = "BottomUpAI"
  state_bucket_name  = "bottomupai.terraform"
  oidc_subject_owner = "BottomUpAI@345462692"
  # The role is AdministratorAccess, so only this repo may assume it. Other
  # repos (the site) get their own narrowly scoped roles.
  oidc_repositories = ["BottomUpAI@345462692/terraform@1432185857"]
  repositories      = keys(module.repositories.repositories)
}
