#!/bin/bash

set -e  # Exit on any error

echo "🧹 Starting EKS Demo Modular Cleanup"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

# Confirmation prompt
print_warning "⚠️  This will destroy ALL infrastructure created by the EKS demo!"
print_warning "This action cannot be undone."
echo ""
read -p "Are you sure you want to proceed? (type 'yes' to confirm): " -r
echo
if [[ ! $REPLY =~ ^yes$ ]]; then
    print_error "Cleanup cancelled."
    exit 1
fi

print_step "Starting cleanup in reverse order..."

# Step 1: Destroy Bastion
print_step "🖥️  Step 1/3: Destroying Bastion Host..."
if [ -d "03-bastion" ]; then
    cd 03-bastion
    
    if [ -f "terraform.tfstate" ] && [ -s "terraform.tfstate" ]; then
        print_step "Destroying bastion infrastructure..."
        terraform destroy -auto-approve
        print_success "✅ Bastion destroyed!"
    else
        print_warning "⚠️  No bastion state found, skipping..."
    fi
    cd ..
else
    print_warning "⚠️  Bastion module directory not found, skipping..."
fi

# Step 2: Destroy EKS
print_step "🎯 Step 2/3: Destroying EKS Cluster and Node Groups..."
if [ -d "02-eks" ]; then
    cd 02-eks
    
    if [ -f "terraform.tfstate" ] && [ -s "terraform.tfstate" ]; then
        print_step "Destroying EKS infrastructure..."
        terraform destroy -auto-approve
        print_success "✅ EKS destroyed!"
    else
        print_warning "⚠️  No EKS state found, skipping..."
    fi
    cd ..
else
    print_warning "⚠️  EKS module directory not found, skipping..."
fi

# Step 3: Destroy Foundation
print_step "📦 Step 3/3: Destroying Foundation (VPC, IAM, Security Groups)..."
if [ -d "01-foundation" ]; then
    cd 01-foundation
    
    if [ -f "terraform.tfstate" ] && [ -s "terraform.tfstate" ]; then
        print_step "Destroying foundation infrastructure..."
        terraform destroy -auto-approve
        print_success "✅ Foundation destroyed!"
    else
        print_warning "⚠️  No foundation state found, skipping..."
    fi
    cd ..
else
    print_warning "⚠️  Foundation module directory not found, skipping..."
fi

print_success "🎉 Cleanup completed successfully!"

print_step "📝 Cleanup Summary:"
echo "- Bastion host and elastic IP destroyed"
echo "- EKS cluster and node groups destroyed"  
echo "- VPC, subnets, and networking destroyed"
echo "- IAM roles and policies destroyed"
echo "- Security groups destroyed"

print_step "🔍 Optional: Clean up Terraform artifacts"
echo "To remove Terraform state files and plans:"
echo "find . -name '*.tfstate*' -delete"
echo "find . -name '*.tfplan' -delete"
echo "find . -name '.terraform' -type d -exec rm -rf {} +"