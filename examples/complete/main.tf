provider "aws" {
  region = "us-west-2"
}


resource "aws_iam_role" "execution_role" {
  name = "example-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "execution_role_policy" {
  role       = aws_iam_role.execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task_role" {
  name = "example-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_ecs_task_definition" "original" {
  family                   = "example-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name      = "web"
      image     = "nginx:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/example-task"
          "awslogs-region"        = "us-west-2"
          "awslogs-stream-prefix" = "web"
        }
      }
    }
  ])
}

resource "aws_cloudwatch_log_group" "task_logs" {
  name              = "/ecs/example-task"
  retention_in_days = 7
}

module "ecs_fargate_task_fis" {
  source = "../../"

  name_prefix        = "example"
  task_definition_id = aws_ecs_task_definition.original.id
  task_role_arn      = aws_iam_role.task_role.arn
  
  fault_injection_types = [
    "network-blackhole-port",
    "network-latency",
    "network-packet-loss"
  ]
  
  tags = {
    Environment = "example"
    Project     = "FIS-Demo"
  }
}