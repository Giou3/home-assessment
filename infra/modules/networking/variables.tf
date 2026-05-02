variable "name_prefix" {
  type = string
}
variable "name_prefix" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}

variable "app_port" {
  type    = number
  default = 8080
}
