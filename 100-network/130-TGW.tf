#############################################
# Transit Gateway (hub) + Route Tables
#############################################
resource "aws_ec2_transit_gateway" "core" {
  description                         = "TGW Core (hub)"
  default_route_table_association     = "disable"
  default_route_table_propagation     = "disable"
  auto_accept_shared_attachments      = "disable"
  dns_support                         = "enable"
  vpn_ecmp_support                    = "enable"
  multicast_support                   = "disable"
  tags = { Name = "tgw-core" }
}

# Route tables on the TGW
resource "aws_ec2_transit_gateway_route_table" "spokes" {
  transit_gateway_id = aws_ec2_transit_gateway.core.id
  tags = { Name = "tgw-rt-spokes" }
}

resource "aws_ec2_transit_gateway_route_table" "inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.core.id
  tags = { Name = "tgw-rt-inspection" }
}


# Routes traffic from spokes to the inspetion vpc attachment  for 0.0.0/0 
resource "aws_ec2_transit_gateway_route" "spokes_default_to_inspection" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
}


#############################################
# VPC Attachments
# - Dev/Spoke: attach Tier2 subnets (one per AZ)
# - Inspection: attach TGW subnets (one per AZ)
#############################################

# Attach Tier2s to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "spoke_dev" {
  transit_gateway_id = aws_ec2_transit_gateway.core.id
  vpc_id             = aws_vpc.main.id
  subnet_ids         = [
    aws_subnet.tier2_subnets[0].id,
    aws_subnet.tier2_subnets[1].id,
    aws_subnet.tier2_subnets[2].id,
  ]
  appliance_mode_support = "disable"
  dns_support            = "enable"

  tags = { Name = "tgw-attach-dev" }
}

#  Attach Inspection VPC to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.core.id
  vpc_id             = aws_vpc.inspection.id
  subnet_ids         = [
    aws_subnet.insp_tgw_subnets[0].id,
    aws_subnet.insp_tgw_subnets[1].id,
    aws_subnet.insp_tgw_subnets[2].id,
  ]
  appliance_mode_support = "enable" # keep symmetric hashing for middleboxes
  dns_support            = "enable"

  tags = { Name = "tgw-attach-inspection" }
}

#############################################
# Associate & Propagate
#############################################
# Spoke attachment uses "spokes" RT; propagates into "inspection" RT
resource "aws_ec2_transit_gateway_route_table_association" "assoc_dev" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.spoke_dev.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}
resource "aws_ec2_transit_gateway_route_table_propagation" "prop_dev_to_insp" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.spoke_dev.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

# Inspection attachment uses "inspection" RT; propagates into "spokes" RT
resource "aws_ec2_transit_gateway_route_table_association" "assoc_insp" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.inspection.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}
resource "aws_ec2_transit_gateway_route_table_propagation" "prop_insp_to_spokes" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.inspection.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}



# Add (or move to 100-variables.tf if you prefer)
variable "spoke_vpc_cidrs" {
  description = "All spoke VPC CIDRs that should be reachable from the Inspection VPC (return path)"
  type        = list(string)
  default     = ["10.0.0.0/16"]  # add "10.1.0.0/16" when you add prod
}

# Public RT in the Inspection VPC already has 0.0.0.0/0 -> IGW
# This adds explicit routes for spoke CIDRs -> TGW (so NAT replies go back via TGW, not IGW)
resource "aws_route" "insp_public_to_spokes" {
  for_each               = toset(var.spoke_vpc_cidrs)
  route_table_id         = aws_route_table.insp_public_rt.id
  destination_cidr_block = each.value
  transit_gateway_id     = aws_ec2_transit_gateway.core.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.inspection,
    aws_route_table.insp_public_rt
  ]
}
