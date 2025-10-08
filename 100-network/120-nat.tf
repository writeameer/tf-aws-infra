# #############################################
# USING Transit Gateway to route to Inspection VPC




# #############################################
# # NAT Gateway Setup (per AZ)
# #############################################

# # Elastic IPs for each NAT
# resource "aws_eip" "nat" {
#   count  = length(aws_subnet.tier1_subnets)
#   domain = "vpc"

#   tags = { Name = "nat-eip-${count.index + 1}" }
#   depends_on = [aws_internet_gateway.main]
# }

# # NAT Gateway in each Tier1 subnet (public)
# resource "aws_nat_gateway" "main" {
#   count         = length(aws_subnet.tier1_subnets)
#   allocation_id = aws_eip.nat[count.index].id
#   subnet_id     = aws_subnet.tier1_subnets[count.index].id

#   tags = { Name = "nat-${data.aws_availability_zones.available.names[count.index]}" }
#   depends_on = [aws_internet_gateway.main]
# }

# output "nat_gateway_ids" {
#   value = aws_nat_gateway.main[*].id
# }
