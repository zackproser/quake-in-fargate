/*
 * variables.tf
 * Common variables to use in various Terraform files (*.tf)
 */

# The AWS region to use for the dev environment's infrastructure
# Currently, Fargate is only available in `us-east-1`.
variable "aws_region" {
  default = "us-east-1"
}

# Tags for the infrastructure
variable "tags" {
  type    = map(string)
  default = {}
}

# The application's name
variable "app" {
  type = string
}

variable "task_memory" {
  type = string
}

variable "task_cpu" {
  type = string
}

variable "image" {
  type = string
}

variable "image_version" {
  type = string
}

# Whether the application is available on the public internet,
# also will determine which subnets will be used (public or private)
variable "internal" {
  default = "true"
}

# The port the container will listen on, used for load balancer health check
# Best practice is that this value is higher than 1024 so the container processes
# isn't running at root.
variable "container_port" {
}

# The port the load balancer will listen on
variable "lb_port" {
  default = "80"
}

# The load balancer protocol
variable "lb_protocol" {
  default = "TCP"
}

# Network configuration

# The VPC to use for the Fargate cluster
variable "vpc" {
  type = string
}

# The private subnets, minimum of 2, that are a part of the VPC(s)
variable "private_subnets" {
  type    = list(string)
  default = []
}

# The public subnets, minimum of 2, that are a part of the VPC(s)
variable "public_subnets" {
}

locals {
  target_subnets = (var.internal == true ? var.private_subnets : var.public_subnets)
}
