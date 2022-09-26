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
# CREATE ECS TASK ROLE 
# ------------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_role" {
  name               = var.app
  assume_role_policy = data.aws_iam_policy_document.task_role_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# assigns the app policy
resource "aws_iam_role_policy" "ecs_task_policy" {
  name   = var.app
  role   = aws_iam_role.ecs_task_role.id
  policy = data.aws_iam_policy_document.ecs_task_policy.json
}

data "aws_iam_policy_document" "ecs_task_policy" {
  statement {
    actions = [
      "*",
    ]

    resources = [
      "*"
    ]
  }
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

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
resource "aws_iam_role" "ecs_service_role" {
  name               = "${var.app}-ecs-service-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "ecs_service_policy" {
  name   = "${var.app}-service-policy"
  role   = aws_iam_role.ecs_service_role.id
  policy = data.aws_iam_policy_document.ecs_task_policy.json

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

resource "aws_ecs_task_definition" "app" {
  family                   = var.app
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "2048"
  memory                   = "4096"
  execution_role_arn       = aws_iam_role.ecs_service_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

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
    subnets          = var.private_subnets
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
  retention_in_days = 0
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP FOR THE AWSVPC TASK NETWORK
# Allow all inbound access on the container port and outbound access
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "nsg_task" {
  name        = var.app
  description = "Limit connections from internal resources while allowing ${var.app} task to connect to all external resources"
  vpc_id      = var.vpc

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


