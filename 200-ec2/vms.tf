# Get vpc
data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["demo-vpc"]
  }
}

# Get all subnets in VPC
data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}


# resource "aws_instance" "test" {
#   for_each = toset(data.aws_subnets.subnets.ids)

#   subnet_id                   = each.value
#   ami                         = data.aws_ami.ubuntu.id
#   key_name                    = "aws01"
#   instance_type               = "t4g.small" # ensure ubuntu AMI is arm64
#   iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

#   tags = {
#     Name = "vm-${substr(each.value, length(each.value)-6, 6)}"
#   }

#   user_data = <<EOF
# #!/bin/bash
# set -euxo pipefail
# apt-get update -y
# apt-get install -y snapd
# snap install amazon-ssm-agent --classic
# systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
# systemctl start  snap.amazon-ssm-agent.amazon-ssm-agent.service
# EOF
# }



# resource "aws_instance" "vms" {
#   for_each = toset(data.aws_subnets.subnets.ids)

#   subnet_id                   = each.value
#   ami                         = data.aws_ssm_parameter.al2023_arm64.value
#   key_name                    = "aws01"
#   instance_type               = "t4g.small" # ensure ubuntu AMI is arm64
#   iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

#   tags = {
#     Name = "vm-${substr(each.value, length(each.value)-6, 6)}"
#   }
# }

# Launch one instance in each subnet with numbered names
resource "aws_instance" "vms" {
  count = length(data.aws_subnets.subnets.ids)

  subnet_id            = data.aws_subnets.subnets.ids[count.index]
  ami                  = data.aws_ssm_parameter.al2023_arm64.value
  key_name             = "aws01"
  instance_type        = "t4g.small"
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  tags = {
    Name = format("vm-%02d", count.index + 1)
  }
}