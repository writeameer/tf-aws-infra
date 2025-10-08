param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$VpcName
)

function Get-VpcId {
    param (
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [string]$VpcName
    )

    $vpcId = aws ec2 describe-vpcs `
        --filters "Name=tag:Name,Values=$VpcName" `
        --query "Vpcs[0].VpcId" `
        --output text

    return $vpcId
}

function Get-MainRouteTable {
    param (
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [string]$VpcId
    )

    aws ec2 describe-route-tables `
        --filters "Name=vpc-id,Values=$VpcId" "Name=association.main,Values=true" `
        --query "RouteTables[0].{RouteTableId:RouteTableId}" `
        --output text
}

# (Optional) show which subnets are associated
function Get-RouteTableAssociations {
    param (
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [string]$RouteTableId
    )

    aws ec2 describe-route-tables `
        --route-table-ids $RouteTableId `
        --query "RouteTables[0].Associations[?SubnetId!=null].{AssociationId:RouteTableAssociationId}" `
        --output text
}

function Remove-RouteTableAssociation {
    param (
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [string]$AssociationId
    )

    "Deleting association $AssociationId"

    aws ec2 disassociate-route-table `
        --association-id $AssociationId `
        --output text
}

# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------
"Deleting all subnet associations from the main route table in VPC: $VpcName"

$vpcId = Get-VpcId -VpcName "$VpcName"
$routeTableId = Get-MainRouteTable -VpcId $vpcId
$associations = Get-RouteTableAssociations -RouteTableId $routeTableId
$associations | ForEach-Object { Remove-RouteTableAssociation -AssociationId $_ }
