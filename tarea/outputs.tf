 
############ RDS Y EC2 ASOCIADO ######################
/*

output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.eks_db.endpoint
}

output "ec2_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.test_instance.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = "ssh -i ~/.ssh/my_key ubuntu@${aws_instance.test_instance.public_ip}"
}
*/



############ Version con módulos ####################




output "oicd_provider_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.vpc-tarea.id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = [for subnet in aws_subnet.private_subnets : subnet.id]
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = [for subnet in aws_subnet.public_subnets : subnet.id]
}

output "private_subnet_names" {
  description = "List of Names of private subnets"
  value       = [for subnet in aws_subnet.private_subnets : subnet.tags["Name"]]
}

output "public_subnet_names" {
  description = "List of Names of public subnets"
  value       = [for subnet in aws_subnet.public_subnets : subnet.tags["Name"]]
}

# output "cluster_id" {
#   description = "The id of the EKS cluster"
#   value       = module.eks.cluster_id
# }

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = module.eks.oidc_provider_arn
}

output "ebs_csi_irsa_role_arn" {
  description = "The ARN of the EBS CSI IRSA role"
  value       = module.ebs_csi_irsa_role.iam_role_arn
}

output "lb_irsa_role_arn" {
  description = "The ARN of the Load Balancer Controller IRSA role"
  value       = module.lb_role.iam_role_arn
}




# output "super_thumbprint" {
#   value = data.tls_certificate.eks.certificates[0].sha1_fingerprint
# }

# output "service_account_name" {
#   value = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
# }


/*
# Output the cluster name
output "eks_cluster_name" {
  value = module.eks.cluster_name
}

# Output the cluster endpoint
output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

# Output the node security group ID
output "node_security_group_id" {
  value = module.eks.node_security_group_id
}


# Output the Kubernetes configuration file
output "kubeconfig" {
  value = module.eks.kubeconfig
}

output "config_map_aws_auth" {
  description = "A kubernetes configuration to authenticate to this EKS cluster."
  value       = module.eks.config_map_aws_auth
}

*/