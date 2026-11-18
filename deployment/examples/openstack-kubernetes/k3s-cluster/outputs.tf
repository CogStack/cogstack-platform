output "created_infra" {
  value = module.openstack_cogstack_infra
}

output "kubeconfig_file" {
  value = module.openstack_cogstack_infra.kubeconfig_file
}

