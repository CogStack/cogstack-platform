
output "created_hosts" {
  value = merge(local.created_nodes,
    {
      (local.controller_host.name) : local.controller_host_instance
  })

  description = "Created Hosts: A map of { hostname: { data } }"
}

output "created_controller_host" {
  value       = local.controller_host_instance
  description = "Created Controller Host: A map of { hostname: { data } }"
}

output "compute_keypair" {
  value = {
    public_key_file  = local.ssh_keys.public_key_file,
    private_key_file = local.ssh_keys.private_key_file,
  }
  description = "Absolute path to a public and private SSH key pair that is granted login on created VMs"
}

output "kubeconfig_file" {
  value       = abspath(local.kubeconfig_file)
  description = "Path to the generated KUBECONFIG file used to connect to kubernetes"
}

output "created_security_group" {
  value       = openstack_networking_secgroup_v2.cogstack_apps_security_group
  description = "Security group associated to the created hosts"
}