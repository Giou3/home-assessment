variable "aws_region" {
  description = "AWS region for this environment."
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name used for tagging."
  type        = string
  default     = "home-assessment"
}

variable "environment" {
  description = "Environment name (prod, staging, etc.)."
  type        = string
  default     = "prod"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for the static site origin."
  type        = string
}
