variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "project_name" {
  type    = string
  default = "home-assessment"
}

variable "environment" {
  type    = string
  default = "staging"
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "public_subnet_cidrs" {
  type = list(string)
  default = [
    "10.1.0.0/24",
    "10.1.1.0/24",
  ]
}

variable "az_count" {
  type    = number
  default = 2
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "cdn_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for static site origin."
}

variable "ecr_repository_name" {
  type    = string
  default = "home-assessment-api"
}

variable "container_image" {
  type        = string
  description = "Container image URI for the API task (typically ECR)."
}

variable "ecs_desired_count" {
  type    = number
  default = 1
}

variable "ecs_task_cpu" {
  type    = number
  default = 256
}

variable "ecs_task_memory" {
  type    = number
  default = 512
}

variable "github_org" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "github_deploy_branch" {
  type    = string
  default = "main"
}

variable "rds_engine" {
  type        = string
  default     = "postgres"
  description = "Stub only: engine type if RDS were provisioned."
}

variable "rds_instance_class" {
  type        = string
  default     = "db.t3.micro"
  description = "Stub only: instance class if RDS were provisioned."
}
