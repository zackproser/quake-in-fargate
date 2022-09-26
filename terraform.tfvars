# These values map directly to the values defined in variables.tf.
# IMPORTANT - You must change at least the vpc, public_subnets, private_subnets, image and 
# image_version variables to point to the correct values in your own AWS account!
app = "quake_in_fargate"
# Make app available over public internet 
internal        = false
container_port  = 27960
lb_port         = 27960
lb_protocol     = "TCP"
vpc             = "vpc-0ac8b331d5b57202e"
public_subnets  = ["subnet-0c8f8509507e23ccb", "subnet-0331d62802807db3e", "subnet-0559e7658ac2ec263"]
private_subnets = ["subnet-0e578d6daf71da063", "subnet-0721b53d88048d9a9", "subnet-097d7272d23409c45"]
task_cpu        = 2048
task_memory     = 4096
image           = "297077893752.dkr.ecr.us-east-1.amazonaws.com/quake-in-fargate"
image_version   = "8a0d644736aa"
