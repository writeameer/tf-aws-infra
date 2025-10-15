# Discover the existing VPC and its subnets created in 100-network
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["demo-vpc"]
  }
}

# Private subnets for nodes (Tier 2)
data "aws_subnets" "private_tier2" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Tier"
    values = ["2"]
  }
}

# Public subnets for load balancers (Tier 1)
data "aws_subnets" "public_tier1" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Tier"
    values = ["1"]
  }
}
