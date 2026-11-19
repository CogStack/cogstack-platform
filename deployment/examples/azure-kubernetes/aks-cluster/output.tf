
output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.this.name
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.aks.resource.name
  sensitive   = true
}

output "kubeconfig_file" {
  value       = abspath(local.kubeconfig_file)
  description = "Path to the generated KUBECONFIG file used to connect to kubernetes"
}
