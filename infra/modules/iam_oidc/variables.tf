variable "name_prefix" {
  type = string
}

variable "github_thumbprints" {
  type    = list(string)
  default = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

variable "github_subject_claims" {
  type        = list(string)
  description = "JWT sub claims allowed to assume the deploy role, e.g. repo:org/repo:ref:refs/heads/main"
}

variable "deploy_role_name" {
  type = string
}

variable "ecr_repository_name" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "ecs_task_definition_family" {
  type        = string
  description = "Task definition family name used by ecs:RegisterTaskDefinition paths."
}

variable "ecs_execution_role_arn" {
  type = string
}

variable "ecs_task_role_arn" {
  type = string
}
