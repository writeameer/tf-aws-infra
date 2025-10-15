variable "region" {
  description = "AWS region"
  type        = string
  default     = "me-central-1"
  
}

# Get each subnet by its ID
data "aws_subnet" "by_id" {
  for_each = toset(data.aws_subnets.subnets.ids)
  id       = each.value
}

# group by AZ → pick first per AZ
locals {
  subnets_by_az     = { for sid, s in data.aws_subnet.by_id : s.availability_zone => sid... }
  one_subnet_per_az = [ for _, ids in local.subnets_by_az : ids[0] ]
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = data.aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.one_subnet_per_az
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = data.aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.one_subnet_per_az
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = data.aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.one_subnet_per_az
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
}
