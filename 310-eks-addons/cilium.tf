#############################################
# Cilium on EKS (ENI IPAM + Kube-Proxy Replacement)
#############################################

locals {
  # Strip https:// prefix from cluster endpoint for kube-proxy replacement
  cluster_host = replace(data.aws_eks_cluster.this.endpoint, "https://", "")
}

# -------------------------------------------------------------------
# IRSA: Cilium Operator requires EC2 ENI permissions for IPAM mode
# -------------------------------------------------------------------
data "aws_iam_policy_document" "cilium_eni" {
  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:AttachNetworkInterface",
      "ec2:DetachNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeAvailabilityZones",

      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:DescribeSecurityGroups",
      "ec2:CreateTags",
      "ec2:DeleteTags"      
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cilium_eni" {
  name   = "cilium-eni-operator"
  policy = data.aws_iam_policy_document.cilium_eni.json
}

resource "aws_iam_role" "cilium_operator" {
  name = "cilium-operator"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.this.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(data.aws_iam_openid_connect_provider.this.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:cilium-operator"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cilium_eni" {
  role       = aws_iam_role.cilium_operator.name
  policy_arn = aws_iam_policy.cilium_eni.arn
}

# -------------------------------------------------------------------
# Cilium Helm Installation
# -------------------------------------------------------------------
resource "helm_release" "cilium" {
  name             = "cilium"
  repository       = "https://helm.cilium.io/"
  chart            = "cilium"
  namespace        = "kube-system"
  create_namespace = false

  reset_values  = true
  force_update  = true
  recreate_pods = true

  set {
    name  = "ipam.mode"
    value = "eni"
  }
  
  set {
    name  = "eni.enabled"
    value = "true"
  }

  # Allow ENI 
  set { 
    name = "eni.awsEnablePrefixDelegation" 
    value = "true" 
  }

  # Recommended hygiene: free unused IPs
  set { 
    name = "eni.awsReleaseExcessIPs"       
    value = "true" 
  }

  set {
    name  = "routingMode"
    value = "native"
  }
  set {
    name  = "autoDirectNodeRoutes"
    value = "true"
  }

  set {
    name  = "kubeProxyReplacement"
    value = "true"
  }

  set {
    name  = "k8sServiceHost"
    value = local.cluster_host
  }
  set {
    name  = "k8sServicePort"
    value = "443"
  }

  set {
    name  = "hubble.enabled"
    value = "false"
  }
  set {
    name  = "envoy.enabled"
    value = "false"
  }
  set {
    name  = "operator.replicas"
    value = "2"
  }

  # This single line is sufficient to use the AWS-specific operator.
  set {
    name  = "operator.image.override"
    value = "quay.io/cilium/operator-aws:v1.18.2"
  }

  set {
    name  = "operator.serviceAccount.create"
    value = "true"
  }
  set {
    name  = "operator.serviceAccount.name"
    value = "cilium-operator"
  }
  set {
    name  = "operator.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cilium_operator.arn
  }

  set {
    name  = "nodeIPAM.enabled"
    value = "true"
  }

  set {
    name  = "operator.extraArgs[0]"
    value = "--enable-node-ipam=true"
  }  
}
