# Setting things up to remove default EKS addons: vpc-cni and kube-proxy

# will comment for now

# locals {
#   cluster_name = var.cluster_name
#   region       = "me-central-1"
# }

# resource "null_resource" "delete_vpc_cni" {
#   triggers = { cluster = local.cluster_name }
#   provisioner "local-exec" {
#     command = "aws eks delete-addon --region ${local.region} --cluster-name ${local.cluster_name} --addon-name vpc-cni || true"
#   }
# }

# resource "null_resource" "delete_kube_proxy" {
#   triggers = { cluster = local.cluster_name }
#   depends_on = [null_resource.delete_vpc_cni]
#   provisioner "local-exec" {
#     command = "aws eks delete-addon --region ${local.region} --cluster-name ${local.cluster_name} --addon-name kube-proxy || true"
#   }
# }