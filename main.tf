locals {
  log_group_name = var.log_group_name != null ? var.log_group_name : "/aws/ecs/fis/${var.name_prefix}"
  
  # Check if we need PID mode configuration
  needs_pid_mode = anytrue([
    contains(var.fault_injection_types, "kill-process"),
    contains(var.fault_injection_types, "network-blackhole-port"),
    contains(var.fault_injection_types, "network-latency"),
    contains(var.fault_injection_types, "network-packet-loss")
  ])
  
  # Check if we need network mode configuration
  needs_network_mode = anytrue([
    contains(var.fault_injection_types, "network-blackhole-port"),
    contains(var.fault_injection_types, "network-latency"),
    contains(var.fault_injection_types, "network-packet-loss")
  ])
}

# Create or use provided log group
resource "aws_cloudwatch_log_group" "ssm_agent" {
  count = var.log_group_name == null ? 1 : 0
  
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

data "aws_cloudwatch_log_group" "existing" {
  count = var.log_group_name != null ? 1 : 0
  
  name = var.log_group_name
}

locals {
  log_group_arn = var.log_group_name != null ? data.aws_cloudwatch_log_group.existing[0].arn : aws_cloudwatch_log_group.ssm_agent[0].arn
  log_group_name_resolved = var.log_group_name != null ? var.log_group_name : aws_cloudwatch_log_group.ssm_agent[0].name
}

# Create SSM role for fault injection
resource "aws_iam_role" "ssm_role" {
  name = "${var.name_prefix}-ssm-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
      }
    ]
  })
  
  description = "Role used by SSM agent for ECS Fault Injection"
  tags        = var.tags
}

# Attach AWS managed policy for SSM
resource "aws_iam_role_policy_attachment" "ssm_managed_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Add required SSM permissions
resource "aws_iam_role_policy" "ssm_permissions" {
  name = "${var.name_prefix}-ssm-permissions"
  role = aws_iam_role.ssm_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:DeleteActivation"]
        Resource = ["*"]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:DeregisterManagedInstance"]
        Resource = ["arn:aws:ssm:*:*:managed-instance/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["${local.log_group_arn}:*"]
      }
    ]
  })
}

# Add SSM permissions to task role
resource "aws_iam_role_policy" "task_role_ssm_permissions" {
  name   = "${var.name_prefix}-task-ssm-permissions"
  role   = element(split("/", var.task_role_arn), length(split("/", var.task_role_arn)) - 1)
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:CreateActivation", "ssm:AddTagsToResource"]
        Resource = ["*"]
      },
      {
        Effect   = "Allow"
        Action   = ["iam:GetRole", "iam:PassRole"]
        Resource = [aws_iam_role.ssm_role.arn]
      }
    ]
  })
}

# Get original task definition details
data "aws_ecs_task_definition" "original" {
  task_definition = element(split("/", var.task_definition_id), length(split("/", var.task_definition_id)) - 1)
}

# Get current region
data "aws_region" "current" {}

# Validate network mode if needed for network-related fault injections
resource "null_resource" "validate_network_mode" {
  count = local.needs_network_mode ? 1 : 0
  
  lifecycle {
    precondition {
      condition     = data.aws_ecs_task_definition.original.network_mode != "bridge"
      error_message = "Network-related fault injection actions cannot be used with bridge network mode. Please use awsvpc, host, or none network mode."
    }
  }
}

# Prepare the SSM agent container definition
locals {
  ssm_agent_container = {
    name      = "amazon-ssm-agent"
    image     = "public.ecr.aws/amazon-ssm-agent/amazon-ssm-agent:latest"
    essential = true
    cpu       = 0
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = local.log_group_name_resolved
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "ssm-agent"
      }
    }
    environment = [
      {
        name  = "MANAGED_INSTANCE_ROLE_NAME"
        value = aws_iam_role.ssm_role.name
      }
    ]
    command = [
      "/bin/bash",
      "-c",
      <<-EOT
      set -e; dnf upgrade -y; dnf install jq procps awscli -y; term_handler() { 
        echo "Deleting SSM activation $ACTIVATION_ID"; 
        if ! aws ssm delete-activation --activation-id $ACTIVATION_ID --region $ECS_TASK_REGION; then 
          echo "SSM activation $ACTIVATION_ID failed to be deleted" 1>&2; 
        fi; 
        MANAGED_INSTANCE_ID=$(jq -e -r .ManagedInstanceID /var/lib/amazon/ssm/registration); 
        echo "Deregistering SSM Managed Instance $MANAGED_INSTANCE_ID"; 
        if ! aws ssm deregister-managed-instance --instance-id $MANAGED_INSTANCE_ID --region $ECS_TASK_REGION; then 
          echo "SSM Managed Instance $MANAGED_INSTANCE_ID failed to be deregistered" 1>&2; 
        fi; 
        kill -SIGTERM $SSM_AGENT_PID; 
      }; 
      trap term_handler SIGTERM SIGINT; 
      if [[ -z $MANAGED_INSTANCE_ROLE_NAME ]]; then 
        echo "Environment variable MANAGED_INSTANCE_ROLE_NAME not set, exiting" 1>&2; 
        exit 1; 
      fi; 
      if ! ps ax | grep amazon-ssm-agent | grep -v grep > /dev/null; then 
        if [[ -n "$ECS_CONTAINER_METADATA_URI_V4" ]] ; then 
          echo "Found ECS Container Metadata, running activation with metadata"; 
          TASK_METADATA=$(curl "$ECS_CONTAINER_METADATA_URI_V4/task"); 
          ECS_TASK_AVAILABILITY_ZONE=$(echo $TASK_METADATA | jq -e -r '.AvailabilityZone'); 
          ECS_TASK_ARN=$(echo $TASK_METADATA | jq -e -r '.TaskARN'); 
          ECS_TASK_REGION=$(echo $ECS_TASK_AVAILABILITY_ZONE | sed 's/.$//')
          echo "Region: $ECS_TASK_REGION"
          echo "Found ECS Task ARN: $ECS_TASK_ARN, Availability Zone: $ECS_TASK_AVAILABILITY_ZONE, Region: $ECS_TASK_REGION";
          CREATE_ACTIVATION_OUTPUT=$(aws ssm create-activation --iam-role $MANAGED_INSTANCE_ROLE_NAME --tags Key=ECS_TASK_AVAILABILITY_ZONE,Value=$ECS_TASK_AVAILABILITY_ZONE Key=ECS_TASK_ARN,Value=$ECS_TASK_ARN Key=FAULT_INJECTION_SIDECAR,Value=true --region $ECS_TASK_REGION); 
          ACTIVATION_CODE=$(echo $CREATE_ACTIVATION_OUTPUT | jq -e -r .ActivationCode); 
          ACTIVATION_ID=$(echo $CREATE_ACTIVATION_OUTPUT | jq -e -r .ActivationId); 
          if ! amazon-ssm-agent -register -code $ACTIVATION_CODE -id $ACTIVATION_ID -region $ECS_TASK_REGION; then
            echo "Failed to register with AWS Systems Manager (SSM), exiting" 1>&2;
            exit 1;
          fi;
          amazon-ssm-agent & SSM_AGENT_PID=$!; 
          wait $SSM_AGENT_PID; 
        else 
          echo "ECS Container Metadata not found, exiting" 1>&2; 
          exit 1; 
        fi; 
      else 
        echo "SSM agent is already running, exiting" 1>&2; 
        exit 1; 
      fi
      EOT
    ]
  }
}

# Update task definition to enable fault injection
resource "aws_ecs_task_definition" "updated" {
  family = data.aws_ecs_task_definition.original.family
  
  # Required attributes that we need to set
  task_role_arn            = var.task_role_arn
  execution_role_arn       = data.aws_ecs_task_definition.original.execution_role_arn
  network_mode             = data.aws_ecs_task_definition.original.network_mode
  cpu                      = data.aws_ecs_task_definition.original.cpu
  memory                   = data.aws_ecs_task_definition.original.memory
  
  # Our modifications
  pid_mode               = local.needs_pid_mode ? "task" : null
  enable_fault_injection = true
  
  # Add the SSM agent container to the existing containers
  container_definitions = jsonencode(
    concat(
      jsondecode(data.aws_ecs_task_definition.original.container_definitions),
      [local.ssm_agent_container]
    )
  )

  # Add dependency on the validation
  depends_on = [null_resource.validate_network_mode]

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}