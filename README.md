# Terraform AWS ECS Fargate Task FIS Module

Terraform module that enables AWS Fault Injection Simulator (FIS) capabilities for ECS Fargate tasks, equivalent to the AWS CDK FargateTaskDefinitionFaultInjection construct.

## Usage

```hcl
module "ecs_fargate_task_fis" {
  source = "path/to/module"

  name_prefix        = "my-app"
  task_definition_id = aws_ecs_task_definition.main.id
  task_role_arn      = aws_ecs_task_definition.main.task_role_arn
  
  fault_injection_types = [
    "network-blackhole-port",
    "network-latency",
    "network-packet-loss"
  ]
}
```

## Features

* Adds an SSM agent container to enable AWS FIS actions
* Creates necessary IAM roles and permissions
* Configures CloudWatch logging for the SSM agent
* Sets appropriate task definition properties (PID mode, network mode)
* Enables fault injection on the task definition
* Supports various fault injection types:
  - `network-latency`
  - `network-packet-loss`
  - `network-blackhole-port`
  - `cpu-stress`
  - `memory-stress`
  - `io-stress`
  - `kill-process`

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 5.31.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.31.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name_prefix | Prefix to use for resource names | `string` | n/a | yes |
| task_definition_id | The ID of the ECS Fargate task definition to enable fault injection on | `string` | n/a | yes |
| task_role_arn | The ARN of the task role used by the ECS task | `string` | n/a | yes |
| fault_injection_types | List of fault injection action types to enable | `list(string)` | `[]` | no |
| log_group_name | Name for the CloudWatch log group (if not provided, one will be created) | `string` | `null` | no |
| log_retention_days | Number of days to retain logs | `number` | `7` | no |
| tags | A map of tags to add to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| ssm_role_arn | The ARN of the SSM role used by the fault injection agent |
| log_group_arn | The ARN of the log group used by the SSM agent container |
| log_group_name | The name of the log group used by the SSM agent container |
| task_definition_arn | The ARN of the updated task definition with fault injection enabled |

## Notes

This module creates a new revision of your task definition with fault injection enabled. To use the updated task definition, you'll need to update your ECS service to use the new task definition revision.

## License

MIT