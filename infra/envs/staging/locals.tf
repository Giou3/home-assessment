locals {
  name_prefix = "${var.project_name}-${var.environment}"

  github_subject_claims = [
    "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_deploy_branch}",
  ]
}
