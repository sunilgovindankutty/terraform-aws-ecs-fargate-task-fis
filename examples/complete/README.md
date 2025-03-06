# Complete ECS Fargate Task FIS Example

This example demonstrates how to use the `terraform-aws-ecs-fargate-task-fis` module to enable fault injection capabilities on an ECS Fargate task definition.

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 4.0.0 |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| ssm_role_arn | The ARN of the SSM role used by the fault injection agent |
| log_group_arn | The ARN of the log group used by the SSM agent container |
| task_definition_arn | The ARN of the updated task definition with fault injection enabled |