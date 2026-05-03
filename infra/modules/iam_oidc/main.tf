data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  ecr_repo_arn = "arn:aws:ecr:${local.region}:${local.account_id}:repository/${var.ecr_repository_name}"

  ecs_cluster_arn = "arn:aws:ecs:${local.region}:${local.account_id}:cluster/${var.ecs_cluster_name}"
  ecs_service_arn = "arn:aws:ecs:${local.region}:${local.account_id}:service/${var.ecs_cluster_name}/${var.ecs_service_name}"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.github_thumbprints
}

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_subject_claims
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = var.deploy_role_name
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
}

data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid = "EcrPush"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
    ]
    resources = [
      local.ecr_repo_arn,
    ]
  }

  statement {
    sid = "EcrAuthToken"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    sid = "EcsDeploy"
    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
    ]
    resources = [
      local.ecs_cluster_arn,
      local.ecs_service_arn,
      "arn:aws:ecs:${local.region}:${local.account_id}:task-definition/${var.ecs_task_definition_family}:*",
    ]
  }

  statement {
    sid = "PassEcsRoles"
    actions = [
      "iam:PassRole",
    ]
    resources = [
      var.ecs_execution_role_arn,
      var.ecs_task_role_arn,
    ]
  }

  statement {
    sid = "LogsForExec"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/ecs/${var.ecs_service_name}:*",
    ]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "github-actions-deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
