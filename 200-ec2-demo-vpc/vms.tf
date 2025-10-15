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

locals {
  subnet_tier = { for id, s in data.aws_subnet.by_id : id => try(s.tags.Tier, "unknown") }
}
# Launch one instance in each subnet with numbered names
# resource "aws_instance" "vms" {
#   count = length(data.aws_subnets.subnets.ids)

#   subnet_id            = data.aws_subnets.subnets.ids[count.index]
#   ami                  = data.aws_ssm_parameter.al2023_arm64.value
#   key_name             = "aws01"
#   instance_type        = "t4g.small"
#   iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

#   # Dynamic security group assignment based on subnet tier
#   vpc_security_group_ids = [
#     local.subnet_tier[data.aws_subnets.subnets.ids[count.index]] == "1" ? aws_security_group.tier1_sg.id :
#     local.subnet_tier[data.aws_subnets.subnets.ids[count.index]] == "2" ? aws_security_group.tier2_sg.id :
#     aws_security_group.tier3_sg.id
#   ]

#   tags = {
#     Tier = local.subnet_tier[data.aws_subnets.subnets.ids[count.index]]
#     Name = format("vm-tier%s-%02d",
#       local.subnet_tier[data.aws_subnets.subnets.ids[count.index]],
#       count.index + 1
#     )
#     SecurityProfile = local.subnet_tier[data.aws_subnets.subnets.ids[count.index]] == "1" ? "web" : (local.subnet_tier[data.aws_subnets.subnets.ids[count.index]] == "2" ? "app" : "data")
#   }
# }
