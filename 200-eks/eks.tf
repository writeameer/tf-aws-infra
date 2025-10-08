# Local values from foundation
locals {
  cluster_name = data.terraform_remote_state.foundation.outputs.cluster_name
  aws_region   = data.terraform_remote_state.foundation.outputs.aws_region
}

# CloudWatch Log Group for EKS cluster
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 7

  tags = {
    Name = "${local.cluster_name}-cluster-logs"
  }
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.cluster_version
  role_arn = data.terraform_remote_state.foundation.outputs.cluster_role_arn

  vpc_config {
    subnet_ids              = concat(data.terraform_remote_state.foundation.outputs.private_subnet_ids, data.terraform_remote_state.foundation.outputs.public_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    security_group_ids      = [data.terraform_remote_state.foundation.outputs.cluster_security_group_id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [aws_cloudwatch_log_group.cluster]

  tags = {
    Name = local.cluster_name
  }
}

# Data source to get cluster's OIDC issuer URL
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# OIDC Identity provider for the cluster
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name = "${local.cluster_name}-oidc"
  }
}

# IAM role for VPC CNI addon
resource "aws_iam_role" "vpc_cni" {
  name = "${local.cluster_name}-vpc-cni-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub": "system:serviceaccount:kube-system:aws-node"
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${local.cluster_name}-vpc-cni-role"
  }
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

# EKS Add-on for VPC CNI (we'll disable this in favor of Cilium)
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.20.3-eksbuild.1"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.vpc_cni.arn

  depends_on = [aws_eks_cluster.main]

  tags = {
    Name = "${local.cluster_name}-vpc-cni"
  }
}

# EKS Add-on for CoreDNS
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  addon_version               = "v1.12.4-eksbuild.1"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.main]

  tags = {
    Name = "${local.cluster_name}-coredns"
  }
}

# EKS Add-on for kube-proxy
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  addon_version               = "v1.34.0-eksbuild.4"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_cluster.main]

  tags = {
    Name = "${local.cluster_name}-kube-proxy"
  }
}
