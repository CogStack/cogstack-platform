locals {
  kubeconfig_file      = "${path.module}/.build/aks-kubeconfig.yaml"
  created_cluster_name = module.aks.resource.name
}