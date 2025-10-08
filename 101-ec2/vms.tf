data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]  
  }

  owners = ["099720109477"] # Canonical
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["demo-vpc"]
  }
}

data "aws_subnet" "subnet" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  filter {
    name   = "tag:Name"
    values = ["public-subnet-1"]
  }
}


data "aws_vpc" "default" {
  default = true
}
# resource "aws_instance" "t4g_small" {
#   ami                         = data.aws_ami.ubuntu_arm64.id
#   instance_type               = "t4g.small"
#   subnet_id                   = aws_subnet.private_subnets[0].id
#   vpc_security_group_ids      = [aws_security_group.ec2_private_sg.id]
#   iam_instance_profile        = aws_iam_instance_profile.ssm_ec2_profile.name
#   associate_public_ip_address = false

#   user_data = <<'EOF'
# #!/bin/bash
# set -euxo pipefail
# apt-get update -y
# apt-get install -y snapd
# snap install amazon-ssm-agent --classic
# systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
# systemctl start  snap.amazon-ssm-agent.amazon-ssm-agent.service
# EOF

#   tags = { Name = "t4g-small-ssm" }
# }

resource "aws_iam_role" "ssm_ec2_role" {
  name = "ec2-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ssm_ec2_role.name
}

resource "aws_instance" "test" {
  subnet_id = data.aws_subnet.subnet.id
  ami           = data.aws_ami.ubuntu.id
  key_name = "aws01"
  instance_type = "t4g.small" 
  tags = { 
    Name = "vm01" 
  }
  associate_public_ip_address = true
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  user_data = <<EOF
    #!/bin/bash
    set -euxo pipefail
    apt-get update -y
    apt-get install -y snapd
    snap install amazon-ssm-agent --classic
    systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    systemctl start  snap.amazon-ssm-agent.amazon-ssm-agent.service
    EOF
}