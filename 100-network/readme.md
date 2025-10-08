# Overiew
As a practice:
- Delete the Default VPC
- When creating VPCs - remove any associations of the default route table to any subnets:
```pwsh
./zDisassociate-MainRouteTable.ps1 -VpcName demo-vpc
```
