variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "health_check_path" {
  type    = string
  default = "/healthz"
}
