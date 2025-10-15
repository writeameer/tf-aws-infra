output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "private_subnet_ids" {
  value = data.aws_subnets.private_tier2.ids
}

output "public_subnet_ids" {
  value = data.aws_subnets.public_tier1.ids
}

# Helper: how to fetch kubeconfig
output "kubeconfig_cmd" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region me-central-1"
}
