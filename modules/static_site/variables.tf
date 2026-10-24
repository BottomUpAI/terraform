variable "domain_name" {
  description = "Apex domain served by this site (www is redirected to it)."
  type        = string
}

variable "zone_id" {
  description = "Route 53 hosted zone ID for domain_name."
  type        = string
}

variable "content_security_policy" {
  description = "Content-Security-Policy header value."
  type        = string
}

variable "log_retention_days" {
  description = "Days to keep CloudFront access logs."
  type        = number
  default     = 90
}
