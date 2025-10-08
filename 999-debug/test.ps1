$subnetId = "subnet-0e9a88e8619956d4d"  
$subnet   = (Get-EC2Subnet -SubnetId $subnetId)
if ($null -eq $subnet) { 
    throw "Subnet $subnetId not found." 
}


########################
# Step 1
########################


Write-Host "`n=== Step 1: Effective route table on the subnet (default must point to TGW) ===" -ForegroundColor Cyan

# Find route table associated to the subnet; fall back to main if none

$vpcId    = $subnet.VpcId
$tier2Cidr= $subnet.CidrBlock
$vpc      = (Get-EC2Vpc -VpcId $vpcId)
"Tier2 VPC: $vpcId  CIDR: $($vpc.CidrBlock)"
"Subnet : $subnetId CIDR: $tier2Cidr"



$routeTableId = ((Get-EC2RouteTable).Associations | ? { $_.SubnetId -eq $subnet.SubnetId}).RouteTableId
$route = Get-EC2RouteTable | ? { $_.RouteTableId -eq $routeTableId }
$default = $route.Routes | ? { $_.DestinationCidrBlock -eq "0.0.0.0/0"}

"EffectiveRouteTableId: $routeTableId"


if ($default -and $default.TransitGatewayId -and $default.State -eq "active") 
{
  Write-Host "PASS: 0.0.0.0/0 → TGW $($default.TransitGatewayId)" -ForegroundColor Green
  $tgwId = $default.TransitGatewayId
} else 
{
  Write-Host "FAIL: Default route not to a Transit Gateway. Current next-hop: $($default.GatewayId ?? $default.NatGatewayId ?? $default.NetworkInterfaceId ?? 'NONE')" -ForegroundColor Red
  Write-Host "Fix (example): Replace-EC2Route -RouteTableId $($rt.RouteTableId) -DestinationCidrBlock 0.0.0.0/0 -TransitGatewayId tgw-xxxxxxxx"
  return
}



########################
# Step 2
########################


Write-Host "`n=== Step 2: Find the TGW attachment for Tier2 VPC and its associated TGW Route Table ===" -ForegroundColor Cyan
$atts = Get-EC2TransitGatewayAttachment | ? { 
    $_.TransitGatewayId -eq "$tgwId" -and 
    $_.ResourceId -eq "$vpcId"
} 

$tier2Att = $atts | Where-Object { $_.ResourceType -eq "vpc" } | Select-Object -First 1
if (-not $tier2Att) { 
    Write-Host "FAIL: No TGW attachment found for VPC $vpcId on $tgwId." -ForegroundColor Red; 
    return 
}

"Tier2 Attachment: $($tier2Att.TransitGatewayAttachmentId)"
"State: $($tier2Att.State)"

Exit 0


# Discover which TGW RT this attachment is associated to (the 'spoke' RT)
$tgwRts = (Get-EC2TransitGatewayRouteTable -Filter @{Name="transit-gateway-id"; Values=$tgwId}).TransitGatewayRouteTables
$assocRt = $null
foreach ($t in $tgwRts) {
  $a = (Get-EC2TransitGatewayRouteTableAssociation -TransitGatewayRouteTableId $t.TransitGatewayRouteTableId).Associations `
      | Where-Object { $_.TransitGatewayAttachmentId -eq $tier2Att.TransitGatewayAttachmentId }
  if ($a) { $assocRt = $t; break }
}
if (-not $assocRt) { Write-Host "FAIL: Tier2 attachment is not associated to any TGW route table." -ForegroundColor Red; return }
"Spoke TGW RT: $($assocRt.TransitGatewayRouteTableId)"

Write-Host "`n=== Step 3: Spoke TGW RT must send default (0.0.0.0/0) to the Egress attachment ===" -ForegroundColor Cyan
$spokeDefault = (Search-EC2TransitGatewayRoute -TransitGatewayRouteTableId $assocRt.TransitGatewayRouteTableId `
  -Filter @{Name="route-search.exact-match"; Values="true"} -Destination "0.0.0.0/0").Routes

if (-not $spokeDefault) { Write-Host "FAIL: No 0.0.0.0/0 route in Spoke TGW RT." -ForegroundColor Red; return }

# identify the attachment used for default
$egressAttId = $spokeDefault.TransitGatewayAttachments.TransitGatewayAttachmentId | Select-Object -First 1
if ($egressAttId) {
  Write-Host "PASS: Spoke TGW RT 0.0.0.0/0 → Attachment $egressAttId" -ForegroundColor Green
} else {
  Write-Host "FAIL: Spoke TGW RT default has no next-hop attachment." -ForegroundColor Red; return
}

Write-Host "`n=== Step 4: Identify the Egress VPC and verify return path in the 'core' TGW RT ===" -ForegroundColor Cyan
$egressAtt = (Get-EC2TransitGatewayAttachment -TransitGatewayAttachmentId $egressAttId).TransitGatewayAttachments[0]
$egressVpcId = $egressAtt.ResourceId
"Egress VPC: $egressVpcId  (via attachment $egressAttId)"

# Find which TGW RT is associated with the egress attachment (often a separate 'core' RT)
$coreRt = $null
foreach ($t in $tgwRts) {
  $a = (Get-EC2TransitGatewayRouteTableAssociation -TransitGatewayRouteTableId $t.TransitGatewayRouteTableId).Associations `
      | Where-Object { $_.TransitGatewayAttachmentId -eq $egressAttId }
  if ($a) { $coreRt = $t; break }
}
if (-not $coreRt) { Write-Host "FAIL: Egress attachment not associated to any TGW route table." -ForegroundColor Red; return }
"Core TGW RT: $($coreRt.TransitGatewayRouteTableId)"

# Check return route for Tier2 CIDR block (VPC CIDR, not just the single subnet)
$tier2VpcCidr = $vpc.CidrBlock
$returnRoute = (Search-EC2TransitGatewayRoute -TransitGatewayRouteTableId $coreRt.TransitGatewayRouteTableId `
  -Filter @{Name="route-search.exact-match"; Values="true"} -Destination $tier2VpcCidr).Routes

if ($returnRoute -and ($returnRoute.TransitGatewayAttachments.TransitGatewayAttachmentId -contains $tier2Att.TransitGatewayAttachmentId)) {
  Write-Host "PASS: Core TGW RT has return route $tier2VpcCidr → Tier2 attachment $($tier2Att.TransitGatewayAttachmentId)" -ForegroundColor Green
} else {
  Write-Host "FAIL: Core TGW RT missing return route for $tier2VpcCidr to Tier2 attachment." -ForegroundColor Red
  Write-Host "Fix (example): Add-EC2TransitGatewayRoute -TransitGatewayRouteTableId $($coreRt.TransitGatewayRouteTableId) -DestinationCidrBlock $tier2VpcCidr -TransitGatewayAttachmentId $($tier2Att.TransitGatewayAttachmentId)"
  return
}

Write-Host "`n=== Step 5: Egress VPC routing (NAT & IGW) ===" -ForegroundColor Cyan
$egressRts = (Get-EC2RouteTable -Filter @{Name="vpc-id"; Values=$egressVpcId}).RouteTables
$igw     = (Get-EC2InternetGateway -Filter @{Name="attachment.vpc-id"; Values=$egressVpcId}).InternetGateways | Select-Object -First 1
$natGws  = (Get-EC2NatGateway -Filter @{Name="vpc-id"; Values=$egressVpcId}).NatGateways

if (-not $igw) { Write-Host "FAIL: No IGW on egress VPC." -ForegroundColor Red; return }
"IGW: $($igw.InternetGatewayId)"
"Found NAT GWs: $(@($natGws.NatGatewayId) -join ', ')"

# Heuristic checks:
# - At least one "public" RT with 0.0.0.0/0 → IGW
# - At least one "egress" RT with 0.0.0.0/0 → NAT GW
$rtToIgw = $egressRts | Where-Object { $_.Routes | Where-Object { $_.DestinationCidrBlock -eq "0.0.0.0/0" -and $_.GatewayId -like "igw-*" } }
$rtToNat = $egressRts | Where-Object { $_.Routes | Where-Object { $_.DestinationCidrBlock -eq "0.0.0.0/0" -and $_.NatGatewayId -like "nat-*" } }

if ($rtToIgw) { Write-Host "PASS: Public route table(s) with default → IGW present." -ForegroundColor Green }
else { Write-Host "FAIL: No default → IGW route in any egress VPC route table." -ForegroundColor Red; return }

if ($rtToNat) { Write-Host "PASS: Egress/private route table(s) with default → NAT GW present." -ForegroundColor Green }
else { Write-Host "FAIL: No default → NAT GW route in any egress VPC route table." -ForegroundColor Red; return }

Write-Host "`n=== Step 6 (optional but recommended): Reachability Analyzer (SSM instance → Internet) ===" -ForegroundColor Cyan
Write-Host "Tip: Use New-EC2NetworkInsightsPath / Start-EC2NetworkInsightsAnalysis from the instance ENI to 8.8.8.8:443 to pinpoint any remaining drop."

Write-Host "`nAll core TGW/egress checks passed. If curl still fails from Tier2, check SG/NACL (even though you said none), DNS, or Inspection/GWLB appliance mode." -ForegroundColor Cyan
