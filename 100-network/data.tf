# Get Availability Zones - usef to distribute subnets
data "aws_availability_zones" "available" {
  state = "available"
}