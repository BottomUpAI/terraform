module "repositories" {
  source = "github.com/bitterbridge/terraform-modules//terraform/modules/repositories?ref=v0.0.778"

  organization_name = "BottomUpAI"
}

module "organization_basic" {
  source = "github.com/bitterbridge/terraform-modules//terraform/modules/organization_basic?ref=v0.0.778"

  organization_name = "BottomUpAI"
  state_bucket_name = "bottomupai.terraform"
  repositories      = keys(module.repositories.repositories)
}
