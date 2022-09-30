# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A DOCKER APP
# These templates show an example of how to run a Docker app on top of Amazon's Fargate Service
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.0.0, < 4.0"
    }
  }
}

# ------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}


# ------------------------------------------------------------------------------
# CREATE ECS TASK EXECUTION ROLE 
# ------------------------------------------------------------------------------

# The ECS task execution role is the IAM role that enables ECS to start ECS tasks (run containers).
# For example, when starting a new task, ECS must contact Elastic Container Registry (ECR) to 
# pull container images, and also needs CloudWatch permissions to write logs to a log group 
# 
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = var.app
  assume_role_policy = data.aws_iam_policy_document.task_role_assume_role_policy.json
}

# allow role to be assumed by ecs and local saml users (for development)
data "aws_iam_policy_document" "task_role_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Here, we opt to use the AWS-managed policy, AmazonECSTaskExecutionRolePolicy 
resource "aws_iam_role_policy_attachment" "ecs_task_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A CLUSTER TO WHICH THE FARGATE SERVICE WILL BE DEPLOYED TO
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_cluster" "fargate_cluster" {
  name = var.app
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A FARGATE SERVICE TO RUN MY ECS TASK
# ---------------------------------------------------------------------------------------------------------------------

# Note, we need only define an ECS task execution role here, which allows ECS to start our tasks (run containers). 
# We don't need an ECS task role, because our task doesn't additionally write to any other AWS Services (such as S3, 
# or DynamoDB, for example)

# See "logConfiguration" below for how we configure our ECS task to write its logs to CloudWatch

resource "aws_ecs_task_definition" "app" {
  family                   = var.app
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = <<DEFINITION
[
  {
    "name": "${var.app}",
    "image": "${var.image}:${var.image_version}",
    "cpu": ${var.task_cpu},
    "memory": ${var.task_memory},
    "command":["/bin/sh", "/usr/local/games/quake3/entrypoint.sh"],
    "essential": true,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${var.app}",
        "awslogs-region": "${var.aws_region}",
        "awslogs-stream-prefix":"${var.app}"
      }
    },
    "portMappings": [{
      "containerPort": ${var.container_port},
      "hostPort": ${var.container_port},
      "protocol": "tcp"
    }],
    "environment": [
      {"name": "SERVER_ARGS", "value": "+map q3dm17 +fraglimit 100000 +timelimit 0"}
    ]
  }
]
DEFINITION


  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.ecs_task]
}

resource "aws_ecs_service" "quake_in_fargate" {
  name            = var.app
  cluster         = aws_ecs_cluster.fargate_cluster.id
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1

  network_configuration {
    security_groups  = [aws_security_group.nsg_task.id]
    subnets          = data.aws_subnets.selected.ids
    assign_public_ip = true
  }

  tags = var.tags

  # [after initial apply] don't override changes made to task_definition
  # from outside of terrraform (i.e.; fargate cli)
  lifecycle {
    ignore_changes = [task_definition]
  }
}

## LOGS ## 

resource "aws_cloudwatch_log_group" "ecs_task" {
  name              = var.app
  retention_in_days = var.log_retention_days
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP FOR THE AWSVPC TASK NETWORK
# Allow all inbound access on the container port and outbound access
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "nsg_task" {
  name        = var.app
  description = "Limit connections from internal resources while allowing ${var.app} task to connect to all external resources"
  vpc_id      = data.aws_vpc.default.id

  tags = var.tags
}

# Allow the world access to the server on 27960
resource "aws_security_group_rule" "task_ingress_rule_tcp" {
  description       = "Allow world to connect to server via TCP"
  type              = "ingress"
  from_port         = var.container_port
  to_port           = var.container_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nsg_task.id
}

# Allow the world access to the server on 27960
resource "aws_security_group_rule" "task_ingress_rule_udp" {
  description       = "Allow world to connect to server via UDP"
  type              = "ingress"
  from_port         = var.container_port
  to_port           = var.container_port
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nsg_task.id
}

resource "aws_security_group_rule" "nsg_task_egress_rule" {
  description = "Allows task to establish connections to all resources"
  type        = "egress"
  from_port   = "0"
  to_port     = "0"
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.nsg_task.id
}


