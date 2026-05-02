variable "github_repository" {
  type = string
}
variable "name_prefix" {
  type = string
}

variable "github_org" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "deploy_role_name" {
  type = string
}

variable "oidc_thumbprints" {
  type    = list(string)
  default = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
