output "waf_module_ready" {
  value = true
}
output "web_acl_arn" {
  value = aws_wafv2_web_acl.this.arn
}
