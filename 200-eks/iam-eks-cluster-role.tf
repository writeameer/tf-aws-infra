#AmazonEKSAutoClusterRole

# IAM role for EKS cluster
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-cluster-role"
  }
}

# Policies for EKS cluster role
locals {
  cluster_policies = [
    "AmazonEKSClusterPolicy",
    "AmazonEKSBlockStoragePolicy",
    "AmazonEKSComputePolicy",
    "AmazonEKSLoadBalancingPolicy",
    "AmazonEKSNetworkingPolicy",
    "AmazonEKSVPCResourceController"
  ]
}

resource "aws_iam_role_policy_attachment" "cluster_policies" {
  for_each   = toset(local.cluster_policies)
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}

