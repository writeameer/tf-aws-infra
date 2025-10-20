#############################################
# IRSA: Karpenter Controller role
#############################################

# Namespace/SA Karpenter will use (Helm step will create them)
locals {
  karpenter_namespace = var.namespace
  karpenter_sa        = "karpenter"
  oidc_provider_arn   = data.aws_iam_openid_connect_provider.this.arn
  oidc_provider_url   = trimprefix(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://")
  sa_sub             = "system:serviceaccount:${local.karpenter_namespace}:${local.karpenter_sa}"
}

# Trust policy for EKS OIDC (IRSA)
data "aws_iam_policy_document" "karpenter_controller_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = [local.sa_sub]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "karpenter_controller" {
  name               = "${var.cluster_name}-karpenter-controller"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_trust.json
  tags = {
    Cluster = var.cluster_name
  }
}

# Attach AWS-managed controller policy (preferred)
# NOTE: If your account/region doesn't have this managed policy,
# we can swap to an inline JSON policy in a later step.
resource "aws_iam_role_policy_attachment" "karpenter_controller_managed" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = "arn:aws:iam::aws:policy/KarpenterControllerPolicy"
}

# The controller must be able to PassRole for the node role below
data "aws_iam_policy_document" "karpenter_controller_passrole" {
  statement {
    effect = "Allow"
    actions = ["iam:PassRole"]
    resources = [aws_iam_role.karpenter_node.arn]
  }
}

resource "aws_iam_policy" "karpenter_controller_passrole" {
  name   = "${var.cluster_name}-karpenter-passrole"
  policy = data.aws_iam_policy_document.karpenter_controller_passrole.json
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_passrole_attach" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller_passrole.arn
}

#############################################
# Instance Role for nodes launched by Karpenter
#############################################

resource "aws_iam_role" "karpenter_node" {
  name = "${var.cluster_name}-karpenter-node"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
  tags = { Cluster = var.cluster_name }
}

# Baseline node policies (works with EKS + Cilium; include SSM for convenience)
resource "aws_iam_role_policy_attachment" "node_eks_worker" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_ro" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_ssm_core" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# (Optional) If you ever switch to aws-cni alongside Cilium (not typical), add:
# resource "aws_iam_role_policy_attachment" "node_cni" {
#   role       = aws_iam_role.karpenter_node.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
# }

resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${var.cluster_name}-karpenter-node"
  role = aws_iam_role.karpenter_node.name
}

#############################################
# Outputs
#############################################
output "karpenter_controller_role_arn" {
  value = aws_iam_role.karpenter_controller.arn
}

output "karpenter_node_role_name" {
  value = aws_iam_role.karpenter_node.name
}

output "karpenter_instance_profile_name" {
  value = aws_iam_instance_profile.karpenter_node.name
}
