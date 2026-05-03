variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "container_name" {
  type = string
}

variable "container_image" {
  type = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "task_cpu" {
  type = number
}

variable "task_memory" {
  type = number
}

variable "subnet_ids" {
  type = list(string)
}

variable "ecs_security_group_ids" {
  type = list(string)
}

variable "assign_public_ip" {
  type    = bool
  default = true
}

variable "target_group_arn" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 14
}
