variable "bucket_name" {
  description = "Name of the S3 bucket used as CloudFront origin."
  type        = string
}

variable "web_acl_id" {
  description = "Optional AWS WAFv2 Web ACL ARN to associate with this distribution (CLOUDFRONT scope)."
  type        = string
  default     = null
}
