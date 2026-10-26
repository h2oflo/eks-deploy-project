output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "Command to point kubectl at the cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "karpenter_instance_profile" {
  description = "Instance profile Karpenter nodes run under"
  value       = module.karpenter.instance_profile_name
}
