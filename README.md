# terraform

Infrastructure for [bottomuplabs.ai](https://bottomuplabs.ai) and the `BottomUpAI` GitHub organization.

## What it manages

- GitHub org plumbing via `bitterbridge/terraform-modules` (`repositories`, `organization_basic`): the state bucket, the GitHub OIDC role, and per-repo Actions variables.
- The `bottomuplabs.ai` Route 53 hosted zone. It was created by the registrar and is **imported**, never recreated; `prevent_destroy` guards it.
- `modules/static_site`: a private S3 bucket behind CloudFront (OAC), with an ACM certificate, a viewer-request function (www → apex, directory index rewrite), security headers, real 404s, and access logs.
- Fastmail mail records, an optional Substack CNAME, and the deploy variables for `BottomUpAI/site`.

## Tests

```sh
npm test          # CloudFront function (node:test)
terraform test    # module/root plan assertions with mock providers
```

## Bootstrap (one time)

1. Apply with local state, which creates the state bucket `bottomupai.terraform` and the OIDC role.
2. Add the `backend "s3"` block and run `terraform init -migrate-state`.
3. From then on, CI plans on pull requests and applies on `main`.
