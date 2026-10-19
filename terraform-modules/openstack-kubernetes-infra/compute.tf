resource "openstack_compute_instance_v2" "kubernetes_server" {

  name      = local.prefix != "" ? "${local.prefix}-${local.controller_host.name}" : local.controller_host.name
  flavor_id = data.openstack_compute_flavor_v2.available_compute_flavors[local.controller_host.flavour].id
  key_pair  = openstack_compute_keypair_v2.compute_keypair.name
  region    = "RegionOne"

  user_data = data.cloudinit_config.init_docker_controller.rendered

  security_groups = ["default",
    openstack_networking_secgroup_v2.cogstack_apps_security_group.name
  ]

  network {
    uuid = local.network_id
  }

  block_device {
    uuid                  = local.controller_host.image_uuid == null ? data.openstack_images_image_v2.ubuntu.id : local.controller_host.image_uuid
    source_type           = "image"
    volume_size           = local.controller_host.volume_size
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }

  lifecycle {
    ignore_changes = [user_data]
  }
}

resource "null_resource" "kubernetes_server_provisioner" {
  depends_on = [openstack_compute_instance_v2.kubernetes_server, openstack_networking_floatingip_associate_v2.kubernetes_server_fip]

  connection {
    user        = "ubuntu"
    host        = local.controller_host_instance.ip_address
    private_key = file(local.ssh_keys.private_key_file)
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait > /tmp/openstack-terraform-remote-exec-provisioner.log || true",
    ]
  }
}

resource "openstack_compute_instance_v2" "kubernetes_nodes" {
  depends_on = [
    openstack_compute_instance_v2.kubernetes_server
  ]

  for_each = { for vm in var.host_instances : vm.name => vm if !vm.is_controller }

  name      = local.prefix != "" ? "${local.prefix}-${each.value.name}" : each.value.name
  flavor_id = data.openstack_compute_flavor_v2.available_compute_flavors[each.value.flavour].id
  key_pair  = openstack_compute_keypair_v2.compute_keypair.name
  region    = "RegionOne"

  user_data = data.cloudinit_config.init_docker[each.key].rendered
  security_groups = ["default",
    openstack_networking_secgroup_v2.cogstack_apps_security_group.name
  ]

  network {
    uuid = local.network_id
  }

  block_device {
    uuid                  = each.value.image_uuid == null ? data.openstack_images_image_v2.ubuntu.id : each.value.image_uuid
    source_type           = "image"
    volume_size           = each.value.volume_size
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }

  lifecycle {
    ignore_changes = [user_data]
  }
}

locals {
  is_default_network    = var.network != null && var.network == { name = "external_4003" }
  nodes_with_exernal_ip = { for node in local.created_nodes : node.name => node if local.is_default_network || node.use_floating_ip }

}
resource "null_resource" "kubernetes_nodes_provisioner" {
  # Provisioner is only used to check for node readiness. Skip for any nodes that are not in the external network,
  # TODO: Filter this provisioner to only run on nodes that have a floating IP if the network is not default
  for_each = local.nodes_with_exernal_ip

  depends_on = [openstack_compute_instance_v2.kubernetes_nodes, openstack_networking_floatingip_associate_v2.kubernetes_nodes_fip]

  connection {
    user        = "ubuntu"
    host        = each.value.ip_address
    private_key = file(local.ssh_keys.private_key_file)
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait > /tmp/openstack-terraform-remote-exec-provisioner.log || true",
    ]
  }
}

# TODO: Read content from files and put into cloud-init config
# data "local_file" "install_docker_sh" {
#   filename = "${path.module}/resources/install-docker.sh"
# }

# data "local_file" "initialize_portainer_binary" {
#   filename = "${path.module}/resources/portainer-init-snapshot.tar.gz"
# }


data "cloudinit_config" "init_docker" {
  for_each = { for vm in var.host_instances : vm.name => vm if !vm.is_controller }

  depends_on = [openstack_compute_instance_v2.kubernetes_server]
  part {
    filename     = "cloud-init-k3s-agent.yaml"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init-k3s-agent.yaml",
      {
        TF_K3S_TOKEN             = random_password.k3s_token.result
        TF_K3S_SERVER_IP_ADDRESS = openstack_compute_instance_v2.kubernetes_server.access_ip_v4
        TF_K3S_NODE_EXTERNAL_IP  = each.value.floating_ip != null && each.value.floating_ip.use_floating_ip ? each.value.floating_ip.address : ""
        TF_K3S_VERSION           = var.k3s_version != null ? var.k3s_version : ""
      }
    )
  }
}

resource "random_password" "k3s_token" {
  length = 32
}

data "cloudinit_config" "init_docker_controller" {
  part {
    filename     = "cloud-init-k3s-server.yaml"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init-k3s-server.yaml",
      {
        TF_K3S_TOKEN            = random_password.k3s_token.result
        TF_K3S_TLS_SAN          = local.controller_host_has_floating_ip ? local.controller_host.floating_ip.address : ""
        TF_K3S_NODE_EXTERNAL_IP = local.controller_host_has_floating_ip ? local.controller_host.floating_ip.address : ""
        TF_K3S_VERSION          = var.k3s_version != null ? var.k3s_version : ""
      }
    )
  }
}

data "openstack_compute_flavor_v2" "available_compute_flavors" {
  for_each = toset([for vm in var.host_instances : vm.flavour])
  name     = each.value
}


data "openstack_networking_network_v2" "network" {
  name = var.network != null && var.network.name != null ? var.network.name : "external_4003"
}

data "openstack_images_image_v2" "ubuntu" {
  name        = var.ubuntu_immage_name
  most_recent = true
}

