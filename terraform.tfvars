# These values map directly to the values defined in variables.tf.
# IMPORTANT - You must change at least the vpc, public_subnets, private_subnets, image and 
# image_version variables to point to the correct values in your own AWS account!
app = "quake_in_fargate"
# Make app available over public internet 
internal       = false
container_port = 27960
lb_port        = 27960
lb_protocol    = "TCP"
image          = "297077893752.dkr.ecr.us-east-1.amazonaws.com/quake-in-fargate"
image_version  = "8a0d644736aa"
