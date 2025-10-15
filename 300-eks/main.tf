#############################################
# EKS using terraform-aws-modules/eks/aws
#############################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = data.aws_vpc.main.id
  subnet_ids = data.aws_subnets.private_tier2.ids

  # Endpoint access
  control_plane_subnet_ids                 = data.aws_subnets.private_tier2.ids
  cluster_endpoint_private_access          = true
  cluster_endpoint_public_access           = true
  cluster_endpoint_public_access_cidrs     = local.public_access_cidrs

  enable_irsa = true
  tags        = var.tags

  # Cluster access entry for the current user
  access_entries = {
    ameer_user = {
      kubernetes_groups = []
      principal_arn     = "arn:aws:iam::855035880829:user/ameer"
      
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    default = {
      # AL2023 on Graviton (ARM64). Valid values include:
      # AL2023_ARM_64_STANDARD | AL2023_x86_64_STANDARD
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = local.supported_instance_types
      capacity_type  = var.use_spot ? "SPOT" : "ON_DEMAND"

      min_size     = var.min_size
      desired_size = var.desired_size
      max_size     = var.max_size

      subnet_ids = data.aws_subnets.private_tier2.ids

      block_device_mappings = {
        root = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 20
            volume_type = "gp3"
            encrypted   = true
          }
        }
      }

      tags = { Name = "${var.cluster_name}-default-ng" }
    }
  }

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }
}
