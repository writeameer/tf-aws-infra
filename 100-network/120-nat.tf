# # Elastic IPs for NAT Gateways
# resource "aws_eip" "nat" {
#   count = length(aws_subnet.public_subnets)

#   domain = "vpc"

#   tags = {
#     Name = "nat-eip-${count.index + 1}"
#   }

#   depends_on = [aws_internet_gateway.main]
# }

# # NAT Gateways
# resource "aws_nat_gateway" "main" {
#   count = length(aws_subnet.public_subnets)

#   allocation_id = aws_eip.nat[count.index].id
#   subnet_id     = aws_subnet.public_subnets[count.index].id

#   depends_on = [aws_internet_gateway.main]
# }