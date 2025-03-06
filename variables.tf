variable "name_prefix" {
  description = "Prefix to use for resource names"
  type        = string
}

variable "task_definition_id" {
  description = "The ID of the ECS Fargate task definition to enable fault injection on"
  type        = string
}

variable "task_role_arn" {
  description = "The ARN of the task role used by the ECS task"
  type        = string
}

variable "fault_injection_types" {
  description = "List of fault injection action types to enable"
  type        = list(string)
  default     = [
    "cpu-stress",
    "io-stress",
    "kill-process",
    "network-blackhole-port",
    "network-latency",
    "network-packet-loss"
  ]
}

variable "log_group_name" {
  description = "Name for the CloudWatch log group (if not provided, one will be created)"
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 7
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}