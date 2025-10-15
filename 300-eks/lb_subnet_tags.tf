# Tag subnets so Service type=LoadBalancer knows where to place ELBs

# Public ELB subnets (internet-facing)
resource "aws_ec2_tag" "public_elb" {
  for_each    = toset(data.aws_subnets.public_tier1.ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

# Private (internal) ELB subnets
resource "aws_ec2_tag" "private_elb" {
  for_each    = toset(data.aws_subnets.private_tier2.ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}
