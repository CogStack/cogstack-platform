
locals {
  random_prefix = random_id.server.b64_url
  prefix        = var.prefix != null ? var.prefix : (var.generate_random_name_prefix ? local.random_prefix : "")
  network_id    = var.network.network_id != null ? var.network.network_id : data.openstack_networking_network_v2.network[0].id
}


locals {
  controller_host                 = one([for host in var.host_instances : host if host.is_controller])
  controller_host_has_floating_ip = local.controller_host.floating_ip != null && local.controller_host.floating_ip.use_floating_ip
  created_controller_host         = openstack_compute_instance_v2.kubernetes_server
  controller_host_instance = {
    name                = local.controller_host.name
    ip_address          = local.controller_host_has_floating_ip ? local.controller_host.floating_ip.address : openstack_compute_instance_v2.kubernetes_server.access_ip_v4
    unique_name         = local.created_controller_host.name
    use_floating_ip     = local.controller_host_has_floating_ip
    internal_ip_address = openstack_compute_instance_v2.kubernetes_server.access_ip_v4
  }

  created_nodes = {
    for node in var.host_instances :
    node.name => {
      ip_address          = node.floating_ip != null && node.floating_ip.use_floating_ip ? node.floating_ip.address : openstack_compute_instance_v2.kubernetes_nodes[node.name].access_ip_v4
      unique_name         = openstack_compute_instance_v2.kubernetes_nodes[node.name].name
      name                = node.name
      use_floating_ip     = node.floating_ip != null && node.floating_ip.use_floating_ip
      internal_ip_address = openstack_compute_instance_v2.kubernetes_nodes[node.name].access_ip_v4
    }
    if !node.is_controller
  }

}

locals {
  output_file_directory = var.output_file_directory != null ? var.output_file_directory : "${path.root}/.build"
  kubeconfig_file       = "${local.output_file_directory}/downloaded-kubeconfig.yaml"
}

resource "random_id" "server" {
  keepers = {
    # Generate a new id each time we recreate the hosts
    cloud_init_config_controller = data.cloudinit_config.init_docker_controller.id
  }

  byte_length = 4
}
