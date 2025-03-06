output "ssm_role_arn" {
  description = "The ARN of the SSM role used by the fault injection agent"
  value       = aws_iam_role.ssm_role.arn
}

output "log_group_arn" {
  description = "The ARN of the log group used by the SSM agent container"
  value       = local.log_group_arn
}

output "log_group_name" {
  description = "The name of the log group used by the SSM agent container"
  value       = local.log_group_name_resolved
}

output "task_definition_arn" {
  description = "The ARN of the updated task definition with fault injection enabled"
  value       = aws_ecs_task_definition.updated.arn
}

output "task_definition_revision" {
  description = "The revision of the updated task definition"
  value       = aws_ecs_task_definition.updated.revision
}