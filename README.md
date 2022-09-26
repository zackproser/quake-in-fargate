# Quake in Fargate 

Run a Quake 3 Arena server as a Fargate Task for fun and learning. This repository includes working Terraform and a Dockerfile to allow you to follow along with the Quake in Fargate tutorial published here. 

# Pre-requisites 
* Fresh copy of Quake 3 Arena - which you can [grab on Steam here](https://store.steampowered.com/app/2200/Quake_III_Arena/)
* AWS account
* Terraform 
* Docker 
* A working installation of the Quake 3 client. I used [ioquake3](https://ioquake3.org/)

# Getting Started

## Step 1. Clone this repository 

## Step 2. Copy your Quake 3 Arena baseq3 folder  
Once you have purchased a copy of Quake 3 Arena, you want to find the `baseq3` folder in the installation directory and copy it to the root directory of your local working copy of this repository. The Docker build in the next step expects you to have a valid `baseq3` folder present before it can succeed. 

## Step 3. Docker build and tag

Follow [these instructions](https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html) to build, tag and push a Docker image to a private Elastic Container Registry (ECR). 

Once that's done, you should have an image URI that follows this pattern: `<aws_account_id>.dkr.ecr.<region>.amazonaws.com/<my-repository>:<tag>`

## Step 4. Setup your terraform.tfvars file 
We'll supply a terraform.tfvars file, which can be used to supply values for our Terraform variables defined in `variables.tf`.

Your initial `terraform.tfvars` file should look something like this: 
```
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
```

To point your Quake in Fargate infra at the new Docker image you just pushed, update the `image` variable to contain the full ECR URI to your image. Set `image_version` to the specific tag of the Docker image. 

You will need to change your `vpc`, `public_subnets`, `private_subnets` variables to point to the actual values for your AWS Account. 

The remainder of the values you can leave unchanged. 

## Step 5. Run Terraform plan and apply 

[Authenticate to your AWS account](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799) using your preferred method, then run `terraform plan`. If the plan looks good, run `terraform apply --auto-approve`.

If successful, the public IP address of your Quake in Fargate server will be printed as one of the Terraform outputs. 

## Step 6. Connect to your Quake in Fargate server via your Quake 3 client 

`./ioquake3.x86_64 connect <quake-in-fargate-server-ip-address>`

