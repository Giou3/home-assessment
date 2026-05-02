## Part 1 Terraform Bug Fixes

This covers all 4 required bug categories: 2 plan failures, 1 silent misconfiguration, and 1 security issue.

### Bug 1 - Wrong S3 reference (plan failure)
What it was:
The CloudFront origin referenced `aws_s3_bucket.static`, but the actual bucket resource is `aws_s3_bucket.static_site`.

Impact:
`terraform plan` fails because the referenced resource does not exist.

Fix:
Updated it to `aws_s3_bucket.static_site.bucket_regional_domain_name`.

### Bug 2 - Broken syntax in forwarded_values (plan failure)
What it was:
`query_string = false` and the `cookies` block were accidentally merged (`falsecookies`), creating invalid HCL syntax.

Impact:
Terraform cannot parse the file, so planning fails immediately.

Fix:
Split into valid syntax:

```hcl
forwarded_values {
  query_string = false

  cookies {
    forward = "none"
  }
}
```

### Bug 3 - HTTP allowed in CloudFront (silent misconfiguration)
What it was:
`viewer_protocol_policy` was set to `allow-all`.

Impact:
Clients can use plain HTTP, which weakens transport security and violates HTTPS-only best practice.

Fix:
Changed it to `redirect-to-https` to enforce HTTPS.

### Bug 4 - public S3 bucket ACL (security issue)
What it was:
The bucket used `acl = public-read`.

Impact:
Objects can be accessed directly from S3, bypassing CloudFront controls; this is typically flagged by security scanners.

Fix:
Removed public ACL behavior and restricted access through CloudFront only by:
- adding `aws_s3_bucket_public_access_block`
- creating `aws_cloudfront_origin_access_identity`
- applying an S3 bucket policy that allows read access only to that CloudFront identity
