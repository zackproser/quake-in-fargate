variable "aws_region" {
  default = "us-east-1"
}

variable "tags" {
  type    = map(string)
  default = {}
}

# The application's name
variable "app" {
  type = string
}

variable "task_memory" {
  type    = string
  default = "4096"
}

variable "task_cpu" {
  type    = string
  default = "2048"
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

# Logs 
variable "log_retention_days" {
  type    = number
  default = 7
}

