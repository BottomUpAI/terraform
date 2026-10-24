# Assertions on modules/static_site, run against mocked AWS (nothing is created).

mock_provider "aws" {
  # The real provider knows domain_validation_options at plan time; mocks
  # need override_during = plan to match that.
  mock_resource "aws_acm_certificate" {
    override_during = plan
    defaults = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
      domain_validation_options = [
        {
          domain_name           = "bottomuplabs.ai"
          resource_record_name  = "_a.bottomuplabs.ai."
          resource_record_type  = "CNAME"
          resource_record_value = "_a.acm-validations.aws."
        },
        {
          domain_name           = "www.bottomuplabs.ai"
          resource_record_name  = "_b.www.bottomuplabs.ai."
          resource_record_type  = "CNAME"
          resource_record_value = "_b.acm-validations.aws."
        },
      ]
    }
  }
  mock_resource "aws_acm_certificate_validation" {
    defaults = {
      certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
    }
  }
  mock_resource "aws_cloudfront_distribution" {
    defaults = {
      arn            = "arn:aws:cloudfront::123456789012:distribution/E000000000000"
      domain_name    = "d000000000000.cloudfront.net"
      hosted_zone_id = "Z2FDTNDATAQYW2"
    }
  }
  mock_resource "aws_cloudfront_function" {
    defaults = {
      arn = "arn:aws:cloudfront::123456789012:function/bottomuplabs-viewer-request"
    }
  }
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn                         = "arn:aws:s3:::bottomuplabs.ai"
      bucket_domain_name          = "bottomuplabs.ai.logs.s3.amazonaws.com"
      bucket_regional_domain_name = "bottomuplabs.ai.s3.us-east-1.amazonaws.com"
    }
  }
}

variables {
  domain_name             = "bottomuplabs.ai"
  zone_id                 = "Z0527416UQ24D0DBN61W"
  content_security_policy = "default-src 'self'"
}

run "static_site" {
  command = plan

  module {
    source = "./modules/static_site"
  }

  assert {
    condition     = aws_cloudfront_distribution.this.restrictions[0].geo_restriction[0].restriction_type == "none"
    error_message = "No geo restriction: readers are worldwide."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https"
    error_message = "Viewers must be redirected to HTTPS."
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.site.block_public_acls,
      aws_s3_bucket_public_access_block.site.block_public_policy,
      aws_s3_bucket_public_access_block.site.ignore_public_acls,
      aws_s3_bucket_public_access_block.site.restrict_public_buckets,
    ])
    error_message = "The site bucket must be fully private."
  }

  assert {
    condition     = toset(aws_cloudfront_distribution.this.aliases) == toset(["bottomuplabs.ai", "www.bottomuplabs.ai"])
    error_message = "Aliases must be exactly apex and www."
  }

  assert {
    condition = length(aws_cloudfront_distribution.this.custom_error_response) > 0 && alltrue([
      for r in aws_cloudfront_distribution.this.custom_error_response :
      r.response_code == 404 && r.response_page_path == "/404.html"
    ])
    error_message = "Missing pages must return a real 404 with /404.html."
  }

  assert {
    condition = (
      length(aws_cloudfront_distribution.this.default_cache_behavior[0].function_association) == 1 &&
      one(aws_cloudfront_distribution.this.default_cache_behavior[0].function_association).event_type == "viewer-request"
    )
    error_message = "Exactly one viewer-request function must be attached."
  }

  assert {
    condition     = aws_cloudfront_response_headers_policy.this.security_headers_config[0].strict_transport_security[0].access_control_max_age_sec == 63072000
    error_message = "HSTS max-age must be two years."
  }

  assert {
    condition     = toset(keys(aws_route53_record.alias)) == toset(["apex-A", "apex-AAAA", "www-A", "www-AAAA"])
    error_message = "Apex and www need both A and AAAA aliases."
  }
}
