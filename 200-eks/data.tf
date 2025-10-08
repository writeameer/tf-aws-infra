# Data sources to get foundation module outputs
# These will reference the foundation module's terraform state

# For now, we'll use local path, but you can change to remote state later
data "terraform_remote_state" "foundation" {
  backend = "local"
  config = {
    path = "../01-foundation/terraform.tfstate"
  }
}

# Data source for EKS optimized AMI
data "aws_ami" "eks_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.cluster_version}-v*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}