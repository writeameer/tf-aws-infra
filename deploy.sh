#!/bin/bash

set -e  # Exit on any error

echo "🚀 Starting EKS Demo Modular Deployment"
echo "========================================"

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

# Check prerequisites
print_step "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install Terraform first."
    exit 1
fi

if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install AWS CLI first."
    exit 1
fi

if [ ! -f ~/.ssh/id_ed25519.pub ]; then
    print_error "SSH public key not found at ~/.ssh/id_ed25519.pub"
    exit 1
fi

print_success "✅ Prerequisites check passed"

# Step 1: Deploy Foundation
print_step "📦 Step 1/3: Deploying Foundation (VPC, IAM, Security Groups)..."
cd 01-foundation

print_step "Initializing Foundation module..."
terraform init

print_step "Planning Foundation deployment..."
terraform plan -out=foundation.tfplan

print_step "Applying Foundation deployment..."
terraform apply foundation.tfplan

print_success "✅ Foundation deployment completed!"

# Step 2: Deploy EKS
print_step "🎯 Step 2/3: Deploying EKS Cluster and Node Groups..."
cd ../02-eks

print_step "Initializing EKS module..."
terraform init

print_step "Planning EKS deployment..."
terraform plan -out=eks.tfplan

print_step "Applying EKS deployment..."
terraform apply eks.tfplan

print_success "✅ EKS deployment completed!"

# Step 3: Deploy Bastion
print_step "🖥️  Step 3/3: Deploying Bastion Host..."
cd ../03-bastion

print_step "Initializing Bastion module..."
terraform init

print_step "Planning Bastion deployment..."
terraform plan -out=bastion.tfplan

print_step "Applying Bastion deployment..."
terraform apply bastion.tfplan

print_success "✅ Bastion deployment completed!"

# Get outputs
print_step "📋 Deployment Summary"
echo "===================="

cd ../01-foundation
echo "🏗️  Foundation Resources:"
terraform output vpc_id
terraform output cluster_name

cd ../02-eks
echo ""
echo "🎯 EKS Cluster:"
terraform output cluster_endpoint
terraform output cluster_status

cd ../03-bastion
echo ""
echo "🖥️  Bastion Host:"
terraform output bastion_public_ip

echo ""
print_success "🎉 Full deployment completed successfully!"
echo ""

print_step "📝 Next Steps:"
echo "1. Connect to bastion host:"
terraform output bastion_ssh_connection
echo ""
echo "2. Install Cilium on bastion host:"
echo "   ssh to bastion, then run the cilium commands from:"
echo "   terraform output cilium_install_command"
echo ""
echo "3. Verify cluster:"
echo "   kubectl get nodes"
echo "   kubectl get pods -A"

cd ..