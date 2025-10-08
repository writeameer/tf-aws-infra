# EKS Demo - Modular Deployment

This is a modular Terraform configuration for deploying an EKS cluster with bastion host in Dubai (me-central-1). The deployment is broken into chronological modules that can be deployed incrementally and tested at each stage.

## 🏗️ Architecture

```
01-foundation (VPC, IAM, Security Groups)
    ↓
02-eks (EKS Cluster + Node Groups)
    ↓  
03-bastion (Bastion Host)
```

## 📁 Module Structure

### **01-foundation** - Core Infrastructure
- **VPC**: 10.0.0.0/16 CIDR with 2 public and 2 private subnets across AZs
- **IAM Roles**: For EKS cluster, worker nodes, and bastion host
- **Security Groups**: Properly configured for cluster communication
- **Networking**: Internet gateway, NAT gateways, route tables

### **02-eks** - EKS Cluster
- **EKS Cluster**: In private subnets with proper logging
- **Node Groups**: Managed node groups in private subnets  
- **Add-ons**: VPC CNI, CoreDNS, kube-proxy (ready for Cilium replacement)
- **OIDC Provider**: For service account integration

### **03-bastion** - Bastion Host
- **EC2 Instance**: In public subnet with pre-installed tools
- **Tools**: kubectl, AWS CLI, Helm, git, htop, jq, tree
- **Auto-config**: kubectl automatically configured for EKS
- **SSH Access**: Using your public key

## 🚀 Deployment Steps

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- SSH key at `~/.ssh/id_ed25519.pub`

### Step 1: Deploy Foundation
```bash
cd 01-foundation
terraform init
terraform plan
terraform apply
```

### Step 2: Deploy EKS Cluster
```bash
cd ../02-eks
terraform init
terraform plan
terraform apply
```

### Step 3: Deploy Bastion Host
```bash
cd ../03-bastion
terraform init
terraform plan
terraform apply
```

## 📝 Quick Deploy Script

For convenience, you can use the deployment script:

```bash
./deploy.sh
```

## 🔧 Individual Module Management

Each module can be managed independently:

```bash
# Foundation only
cd 01-foundation
terraform plan
terraform apply

# EKS only (requires foundation to be deployed)
cd 02-eks
terraform plan
terraform apply

# Bastion only (requires foundation and EKS)
cd 03-bastion
terraform plan
terraform apply
```

## 🧹 Cleanup

To destroy everything (in reverse order):

```bash
# Destroy bastion first
cd 03-bastion && terraform destroy -auto-approve

# Then EKS
cd ../02-eks && terraform destroy -auto-approve

# Finally foundation
cd ../01-foundation && terraform destroy -auto-approve
```

Or use the cleanup script:
```bash
./cleanup.sh
```

## ⚙️ Customization

Each module has its own `variables.tf` file for customization:

- **01-foundation/variables.tf**: VPC CIDRs, region, cluster name
- **02-eks/variables.tf**: Kubernetes version, node instance types, capacity
- **03-bastion/variables.tf**: Bastion instance type

## 📊 Module Dependencies

```
Foundation Outputs → EKS Module
├─ VPC ID, Subnet IDs
├─ IAM Role ARNs  
├─ Security Group IDs
└─ Common variables

Foundation + EKS Outputs → Bastion Module
├─ All foundation outputs
├─ Cluster name, endpoint
└─ Auto-configure kubectl
```

## 🎯 Benefits of Modular Approach

1. **Incremental Deployment**: Test each layer before proceeding
2. **Independent Management**: Update specific components without affecting others
3. **Faster Iterations**: Smaller blast radius for changes
4. **Clear Dependencies**: Explicit relationships between components
5. **Easier Troubleshooting**: Isolate issues to specific modules

## 📋 Post-Deployment

After successful deployment:

1. **Get bastion SSH command**:
   ```bash
   cd 03-bastion && terraform output bastion_ssh_connection
   ```

2. **Connect to bastion**:
   ```bash
   ssh -i ~/.ssh/id_ed25519 ec2-user@<BASTION_IP>
   ```

3. **Install Cilium** (on bastion host):
   ```bash
   cd 03-bastion && terraform output cilium_install_command
   # Copy and run the commands on the bastion host
   ```

4. **Verify cluster**:
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

## 🔄 State Management

Currently using local state files. For production:
1. Set up remote state backend (S3 + DynamoDB)
2. Update `data.tf` files in each module to use remote backend
3. Use state locking for concurrent access protection

## 🛠️ Troubleshooting

- **Module dependency issues**: Ensure previous modules are successfully applied
- **State file missing**: Check that the previous module's `terraform.tfstate` exists
- **Permission issues**: Verify IAM permissions for all required services
- **Resource conflicts**: Check for naming conflicts if redeploying