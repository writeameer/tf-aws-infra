# outputs.tf
# Output important resource IDs for testing and reference

output "security_group_ids" {
  description = "Security group IDs by tier"
  value = {
    tier1         = aws_security_group.tier1_sg.id
    tier2         = aws_security_group.tier2_sg.id
    tier3         = aws_security_group.tier3_sg.id
    vpc_endpoints = aws_security_group.vpc_endpoints_sg.id
    debug         = aws_security_group.debug_sg.id
  }
}

# output "instance_details" {
#   description = "Instance details by tier for network testing"
#   value = {
#     for i, instance in aws_instance.vms : instance.tags.Name => {
#       instance_id    = instance.id
#       private_ip     = instance.private_ip
#       subnet_id      = instance.subnet_id
#       tier          = instance.tags.Tier
#       security_profile = instance.tags.SecurityProfile
#       availability_zone = instance.availability_zone
#     }
#   }
# }

# output "tier2_instances_for_testing" {
#   description = "Tier 2 instance IDs and IPs for TGW connectivity testing"
#   value = {
#     for i, instance in aws_instance.vms : instance.tags.Name => {
#       instance_id = instance.id
#       private_ip  = instance.private_ip
#       subnet_id   = instance.subnet_id
#     } if instance.tags.Tier == "2"
#   }
# }

output "vpc_endpoints" {
  description = "VPC endpoint IDs for SSM access"
  value = {
    ssm         = aws_vpc_endpoint.ssm.id
    ec2messages = aws_vpc_endpoint.ec2messages.id
    ssmmessages = aws_vpc_endpoint.ssmmessages.id
  }
}

output "testing_commands" {
  description = "Useful commands for network connectivity testing"
  value = {
    list_tier2_instances = "aws ec2 describe-instances --filters 'Name=tag:Tier,Values=2' --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' --output table"
    ssm_connect_example  = "aws ssm start-session --target <instance-id>"
    test_internet        = "curl -I https://google.com"
    test_dns            = "nslookup google.com"
  }
}