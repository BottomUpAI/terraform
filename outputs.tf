output "site_bucket_name" {
  value = module.site.bucket_name
}

output "site_distribution_id" {
  value = module.site.distribution_id
}

output "github_oidc_role" {
  value = module.organization_basic.github_oidc_role
}
