#AmazonEKSAutoClusterRole

# IAM role for EKS cluster
resource "aws_iam_role" "pod" {
  name = "${var.cluster_name}-pod-identity-role"

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
    Name = "${var.cluster_name}-pod-identity-role"
  }
}

# Policies for EKS cluster role
locals {
  pod_policies = [
    "AmazonEKS_CNI_Policy"
  ]
}

resource "aws_iam_role_policy_attachment" "pod_policies" {
  for_each   = toset(local.pod_policies)
  role       = aws_iam_role.pod.name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}

