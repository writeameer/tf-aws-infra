# Local values from remote states
locals {
  cluster_name = data.terraform_remote_state.foundation.outputs.cluster_name
  aws_region   = data.terraform_remote_state.foundation.outputs.aws_region
}

# Create AWS key pair from local public key
resource "aws_key_pair" "bastion" {
  key_name   = "${local.cluster_name}-bastion-key"
  public_key = data.local_file.public_key.content

  tags = {
    Name = "${local.cluster_name}-bastion-key"
  }
}

# User data script to install kubectl and AWS CLI
locals {
  user_data = <<-EOF
#!/bin/bash
yum update -y

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install git and other useful tools
yum install -y git htop tree jq

# Configure kubectl for EKS
mkdir -p /home/ec2-user/.kube
aws eks update-kubeconfig --region ${local.aws_region} --name ${local.cluster_name} --kubeconfig /home/ec2-user/.kube/config
chown -R ec2-user:ec2-user /home/ec2-user/.kube

# Set up bash completion for kubectl
echo 'source <(kubectl completion bash)' >> /home/ec2-user/.bashrc
echo 'alias k=kubectl' >> /home/ec2-user/.bashrc
echo 'complete -o default -F __start_kubectl k' >> /home/ec2-user/.bashrc
EOF
}

# Bastion host EC2 instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.bastion_instance_type
  key_name               = aws_key_pair.bastion.key_name
  vpc_security_group_ids = [data.terraform_remote_state.foundation.outputs.bastion_security_group_id]
  subnet_id              = data.terraform_remote_state.foundation.outputs.public_subnet_ids[0]
  iam_instance_profile   = data.terraform_remote_state.foundation.outputs.bastion_instance_profile_name

  user_data = base64encode(local.user_data)

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "${local.cluster_name}-bastion"
  }

  depends_on = [data.terraform_remote_state.eks]
}

# Elastic IP for bastion host
resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = {
    Name = "${local.cluster_name}-bastion-eip"
  }

  depends_on = [data.terraform_remote_state.foundation]
}