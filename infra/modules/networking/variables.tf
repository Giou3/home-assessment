variable "name_prefix" {
  type        = string
  description = "Prefix used for resource Name tags."
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "One CIDR per AZ; length must match az_count."
}

variable "az_count" {
  type    = number
  default = 2
}

variable "app_port" {
  type    = number
  default = 8080
}
