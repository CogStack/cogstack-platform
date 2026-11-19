output "created_controller_host" {
  value = module.openstack_cogstack_infra.created_controller_host
}

output "created_hosts" {
  value = module.openstack_cogstack_infra.created_hosts
}

output "ssh_keys" {
  sensitive = true
  value     = module.openstack_cogstack_infra.compute_keypair
}

output "portainer_instance" {
  sensitive = true
  value     = module.openstack_cogstack_infra.portainer_instance
}