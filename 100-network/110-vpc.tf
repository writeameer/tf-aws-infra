# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "demo-vpc"
  }
}

# Get the main route table of the VPC
data "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}
# Tag the main route table
resource "aws_default_route_table" "main_name" {
  
  default_route_table_id = aws_vpc.main.default_route_table_id
  tags = {
    Name = "Main Route Table for ${aws_vpc.main.tags["Name"]}"
  }
}

# Internet Gateway for the VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}


#------------------------------------------------------------------------------------------------------
# Public Subnets and route to Internet Gateway
#------------------------------------------------------------------------------------------------------

# Public Subnets
resource "aws_subnet" "public_subnets" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# # Route table for public subnets
# resource "aws_route_table" "public_route_table" {
#   vpc_id = aws_vpc.main.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.main.id
#   }
# }

# # Route table associations for public subnets
# resource "aws_route_table_association" "public_route_associations" {
#   count = length(aws_subnet.public_subnets)

#   subnet_id      = aws_subnet.public_subnets[count.index].id
#   route_table_id = aws_route_table.public_route_table.id
# }


#------------------------------------------------------------------------------------------------------
# Private Subnets and route to NAT Gateway
#------------------------------------------------------------------------------------------------------


# Private Subnets
resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# # Route tables for private subnets
# resource "aws_route_table" "private_route_table" {
#   count = length(aws_subnet.private_subnets)

#   vpc_id = aws_vpc.main.id

#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.main[count.index].id
#   }
# }

# # Route table associations for private subnets
# resource "aws_route_table_association" "private_route_associations" {
#   count = length(aws_subnet.private_subnets)

#   subnet_id      = aws_subnet.private_subnets[count.index].id
#   route_table_id = aws_route_table.private_route_table[count.index].id
# }