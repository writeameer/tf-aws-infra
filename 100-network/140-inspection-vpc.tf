#############################################
# Inspection VPC
#############################################
resource "aws_vpc" "inspection" {
  cidr_block           = var.inspection_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "inspection-vpc" }
}

resource "aws_internet_gateway" "insp_igw" {
  vpc_id = aws_vpc.inspection.id
  tags   = { Name = "igw-inspection" }
}

# Public subnets for NAT (per AZ)
resource "aws_subnet" "insp_public_subnets" {
  count = length(var.insp_public_cidrs)
  vpc_id                  = aws_vpc.inspection.id
  cidr_block              = var.insp_public_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "insp-public-${count.index + 1}"
    Zone = data.aws_availability_zones.available.names[count.index]
  }
}

# TGW attachment subnets (private)
resource "aws_subnet" "insp_tgw_subnets" {
  count = length(var.insp_tgw_cidrs)
  vpc_id            = aws_vpc.inspection.id
  cidr_block        = var.insp_tgw_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "insp-tgw-${count.index + 1}"
    Zone = data.aws_availability_zones.available.names[count.index]
  }
}

#############################################
# NAT in Inspection VPC (central egress today)
#############################################
resource "aws_eip" "insp_nat_eip" {
  count  = length(aws_subnet.insp_public_subnets)
  domain = "vpc"
  tags = { Name = "insp-nat-eip-${count.index + 1}" }
  depends_on = [aws_internet_gateway.insp_igw]
}
resource "aws_nat_gateway" "insp_nat" {
  count         = length(aws_subnet.insp_public_subnets)
  allocation_id = aws_eip.insp_nat_eip[count.index].id
  subnet_id     = aws_subnet.insp_public_subnets[count.index].id
  tags = { Name = "insp-nat-${data.aws_availability_zones.available.names[count.index]}" }
  depends_on = [aws_internet_gateway.insp_igw]
}

# Route tables
resource "aws_route_table" "insp_public_rt" {
  vpc_id = aws_vpc.inspection.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.insp_igw.id
  }
  tags = { Name = "insp-public-rt" }
}
resource "aws_route_table_association" "insp_public_assoc" {
  count          = length(aws_subnet.insp_public_subnets)
  subnet_id      = aws_subnet.insp_public_subnets[count.index].id
  route_table_id = aws_route_table.insp_public_rt.id
}

# For traffic arriving from TGW, default to NAT in same AZ (centralized egress)
resource "aws_route_table" "insp_tgw_rt" {
  count = length(aws_subnet.insp_tgw_subnets)
  vpc_id = aws_vpc.inspection.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.insp_nat[count.index].id
  }
  tags = { Name = "insp-tgw-rt-${count.index + 1}" }
}
resource "aws_route_table_association" "insp_tgw_assoc" {
  count          = length(aws_subnet.insp_tgw_subnets)
  subnet_id      = aws_subnet.insp_tgw_subnets[count.index].id
  route_table_id = aws_route_table.insp_tgw_rt[count.index].id
}

#############################################
# (Later) Drop AWS Network Firewall here:
# - create firewall subnets, firewall policy + rule groups (FQDN allowlist)
# - change insp_tgw_rt default next hop from NAT -> NFW endpoint
#############################################
