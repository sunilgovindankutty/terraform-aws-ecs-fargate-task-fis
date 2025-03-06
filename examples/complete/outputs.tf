output "ssm_role_arn" {
  description = "The ARN of the SSM role used by the fault injection agent"
  value       = module.ecs_fargate_task_fis.ssm_role_arn
}

output "log_group_arn" {
  description = "The ARN of the log group used by the SSM agent container"
  value       = module.ecs_fargate_task_fis.log_group_arn
}

output "task_definition_arn" {
  description = "The ARN of the updated task definition with fault injection enabled"
  value       = module.ecs_fargate_task_fis.task_definition_arn
}