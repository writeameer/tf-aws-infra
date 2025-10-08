# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.cluster_name}-nodes"
  node_role_arn   = data.terraform_remote_state.foundation.outputs.nodes_role_arn
  subnet_ids      = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  instance_types  = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_capacity
    max_size     = var.node_max_capacity
    min_size     = var.node_min_capacity
  }

  update_config {
    max_unavailable = 1
  }

  # Remote access configuration
  remote_access {
    ec2_ssh_key               = aws_key_pair.nodes.key_name
    source_security_group_ids = [data.terraform_remote_state.foundation.outputs.bastion_security_group_id]
  }

  tags = {
    Name = "${local.cluster_name}-nodes"
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# SSH key pair for node group (we'll create a separate one for nodes)
resource "aws_key_pair" "nodes" {
  key_name   = "${local.cluster_name}-nodes-key"
  public_key = data.local_file.public_key.content

  tags = {
    Name = "${local.cluster_name}-nodes-key"
  }
}

# Read the public key file
data "local_file" "public_key" {
  filename = pathexpand("~/.ssh/id_ed25519.pub")
}