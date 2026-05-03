module "networking" {
  source = "../../modules/networking"

  name_prefix         = local.name_prefix
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  az_count            = var.az_count
  app_port            = var.app_port
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name = var.ecr_repository_name
}

module "ecs_iam" {
  source = "../../modules/ecs_iam"

  name_prefix = local.name_prefix
}

module "iam" {
  source = "../../modules/iam_oidc"

  name_prefix = local.name_prefix

  github_subject_claims = local.github_subject_claims

  deploy_role_name = "${local.name_prefix}-gha-deploy"

  ecr_repository_name = module.ecr.repository_name

  ecs_cluster_name           = "${local.name_prefix}-cluster"
  ecs_service_name           = "${local.name_prefix}-api"
  ecs_task_definition_family = "${local.name_prefix}-api"

  ecs_execution_role_arn = module.ecs_iam.execution_role_arn
  ecs_task_role_arn      = module.ecs_iam.task_role_arn
}

module "alb" {
  source = "../../modules/alb"

  name               = "${local.name_prefix}-alb"
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.networking.alb_security_group_id]
  app_port           = var.app_port
  health_check_path  = "/healthz"
}

module "ecs" {
  source = "../../modules/ecs_service"

  aws_region = var.aws_region

  cluster_name = "${local.name_prefix}-cluster"
  service_name = "${local.name_prefix}-api"

  container_name  = "api"
  container_image = var.container_image
  container_port  = var.app_port

  desired_count = var.ecs_desired_count
  task_cpu      = var.ecs_task_cpu
  task_memory   = var.ecs_task_memory

  subnet_ids             = module.networking.public_subnet_ids
  ecs_security_group_ids = [module.networking.ecs_security_group_id]

  target_group_arn = module.alb.target_group_arn

  execution_role_arn = module.ecs_iam.execution_role_arn
  task_role_arn      = module.ecs_iam.task_role_arn

  depends_on = [module.alb]
}

module "cdn" {
  source = "../../modules/cdn"

  bucket_name = var.cdn_bucket_name
}
