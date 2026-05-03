output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "cloudfront_domain_name" {
  value = module.cdn.cloudfront_domain_name
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "github_deploy_role_arn" {
  value = module.iam.github_deploy_role_arn
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}
