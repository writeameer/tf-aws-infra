#############################################
# VPC + IGW
#############################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "demo-vpc" }
}

# Tag the main route table (should stay unassociated)
resource "aws_default_route_table" "main_name" {
  default_route_table_id = aws_vpc.main.default_route_table_id
  tags = { Name = "Main Route Table for ${aws_vpc.main.tags["Name"]}" }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "igw-${aws_vpc.main.tags["Name"]}" }
}

#############################################
# Tier1 (Public) Subnets + RT to IGW
#############################################

# Create one subnet per AZ
resource "aws_subnet" "tier1_subnets" {
  count = length(var.tier1_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.tier1_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "tier1-subnet-${count.index + 1}"
    Tier = "1"
  }
}

# Create route to IGW
resource "aws_route_table" "tier1_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "tier1-rt-igw" }
}

# Associate rout

resource "aws_route_table_association" "tier1_assoc" {
  count          = length(aws_subnet.tier1_subnets)
  subnet_id      = aws_subnet.tier1_subnets[count.index].id
  route_table_id = aws_route_table.tier1_rt.id
}

#############################################
# Tier2 (App) Subnets + per-AZ RT to NAT
#############################################

# Create subnets
resource "aws_subnet" "tier2_subnets" {
  count = length(var.tier2_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.tier2_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "tier2-subnet-${count.index + 1}"
    Tier = "2"
  }
}

# Create route to NAT Gateway
resource "aws_route_table" "tier2_rt" {
  count = length(aws_subnet.tier2_subnets)
  vpc_id = aws_vpc.main.id

  # route {
  #   cidr_block     = "0.0.0.0/0"
  #   nat_gateway_id = aws_nat_gateway.main[count.index].id
  # }

  route {
    cidr_block       = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.core.id
  }

  tags = { Name = "tier2-rt-${count.index + 1}" }
}

# Associate route tables
resource "aws_route_table_association" "tier2_assoc" {
  count          = length(aws_subnet.tier2_subnets)
  subnet_id      = aws_subnet.tier2_subnets[count.index].id
  route_table_id = aws_route_table.tier2_rt[count.index].id
}

#############################################
# Tier3 (Data) Subnets + per-AZ RT to NAT
#############################################

resource "aws_subnet" "tier3_subnets" {
  count = length(var.tier3_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.tier3_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "tier3-subnet-${count.index + 1}"
    Tier = "3"
  }
}

resource "aws_route_table" "tier3_rt" {
  count = length(aws_subnet.tier3_subnets)
  vpc_id = aws_vpc.main.id

  # route {
  #   cidr_block     = "0.0.0.0/0"
  #   nat_gateway_id = aws_nat_gateway.main[count.index].id
  # }

  route {
    cidr_block       = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.core.id
  }

  tags = { Name = "tier3-rt-${count.index + 1}" }
}

resource "aws_route_table_association" "tier3_assoc" {
  count          = length(aws_subnet.tier3_subnets)
  subnet_id      = aws_subnet.tier3_subnets[count.index].id
  route_table_id = aws_route_table.tier3_rt[count.index].id
}

#############################################
# Outputs
#############################################

output "vpc_id" {
  value = aws_vpc.main.id
}

output "tier1_subnet_ids" {
  value = aws_subnet.tier1_subnets[*].id
}

output "tier2_subnet_ids" {
  value = aws_subnet.tier2_subnets[*].id
}

output "tier3_subnet_ids" {
  value = aws_subnet.tier3_subnets[*].id
}
