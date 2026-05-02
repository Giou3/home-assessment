output "iam_oidc_module_ready" {
  value = true
}
output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}

output "task_execution_role_arn" {
  value = aws_iam_role.task_execution.arn
}

output "task_runtime_role_arn" {
  value = aws_iam_role.task_runtime.arn
}
