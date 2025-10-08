output "bastion_instance_id" {
  description = "ID of the bastion host"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Elastic IP associated with the bastion host"
  value       = aws_eip.bastion.public_ip
}

output "bastion_public_dns" {
  description = "Public DNS name assigned to the bastion host"
  value       = aws_instance.bastion.public_dns
}

output "bastion_ssh_connection" {
  description = "SSH command to connect to bastion host"
  value       = "ssh -i ~/.ssh/id_ed25519 ec2-user@${aws_eip.bastion.public_ip}"
}

output "kubectl_config_command" {
  description = "Command to configure kubectl for the EKS cluster (already done in user data)"
  value       = "aws eks update-kubeconfig --region ${local.aws_region} --name ${local.cluster_name}"
}

output "cilium_install_command" {
  description = "Commands to install Cilium CNI (run these on bastion host after connecting)"
  value       = data.terraform_remote_state.eks.outputs.cilium_install_command
}