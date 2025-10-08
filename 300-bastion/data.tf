# Data sources to get foundation and EKS module outputs
data "terraform_remote_state" "foundation" {
  backend = "local"
  config = {
    path = "../01-foundation/terraform.tfstate"
  }
}

data "terraform_remote_state" "eks" {
  backend = "local"
  config = {
    path = "../02-eks/terraform.tfstate"
  }
}

# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Read the public key file
data "local_file" "public_key" {
  filename = pathexpand("~/.ssh/id_ed25519.pub")
}