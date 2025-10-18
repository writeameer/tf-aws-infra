#!/usr/bin/env pwsh

# Script to create a tarball of Terraform directories excluding temporary files
# Creates current.tar.gz with 100-network, 200-ec2-demo-vpc, and 300-eks directories

$OutputFile = "current.tar.gz"
$Directories = @("100-network", "200-ec2-demo-vpc", "300-eks","310-eks-addons")

# Remove existing tarball if it exists
if (Test-Path $OutputFile) {
    Write-Host "Removing existing $OutputFile..."
    Remove-Item $OutputFile -Force
}

# Check if directories exist
$ExistingDirs = @()
foreach ($dir in $Directories) {
    if (Test-Path $dir) {
        $ExistingDirs += $dir
        Write-Host "Found directory: $dir"
    } else {
        Write-Warning "Directory $dir not found, skipping..."
    }
}

if ($ExistingDirs.Count -eq 0) {
    Write-Error "No directories found to archive!"
    exit 1
}

# Create tarball using tar with exclude options
Write-Host "Creating tarball: $OutputFile"

$excludeOptions = @(
    "--exclude=.terraform",
    "--exclude=.git", 
    "--exclude=node_modules",
    "--exclude=.vscode",
    "--exclude=*.tfstate",
    "--exclude=*.tfstate.backup",
    "--exclude=.terraform.lock.hcl",
    "--exclude=terraform.tfplan",
    "--exclude=*.log"
)

# Build the tar command
$tarArgs = @("-czf", $OutputFile) + $excludeOptions + $ExistingDirs
tar @tarArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "Successfully created $OutputFile" -ForegroundColor Green
    
    # Show file size
    $FileSize = (Get-Item $OutputFile).Length
    $FileSizeMB = [math]::Round($FileSize / 1MB, 2)
    $FileSizeKB = [math]::Round($FileSize / 1KB, 2)
    
    if ($FileSizeMB -gt 1) {
        Write-Host "File size: $FileSizeMB MB" -ForegroundColor Cyan
    } else {
        Write-Host "File size: $FileSizeKB KB" -ForegroundColor Cyan
    }
} else {
    Write-Error "Failed to create tarball"
    exit 1
}
