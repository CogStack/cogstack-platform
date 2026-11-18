
resource "openstack_compute_instance_v2" "cogstack_ops_compute" {
  depends_on = [openstack_networking_secgroup_rule_v2.cogstack_apps_port_rules["22-SSH"]]
  for_each   = { for vm in var.host_instances : vm.name => vm }
  name       = "${local.random_prefix}-${each.value.name}"
  flavor_id  = data.openstack_compute_flavor_v2.available_compute_flavors[each.value.flavour].id
  key_pair   = openstack_compute_keypair_v2.compute_keypair.name
  region     = "RegionOne"

  user_data = each.value.is_controller ? data.cloudinit_config.init_docker_controller.rendered : data.cloudinit_config.init_docker.rendered
  security_groups = ["default",
    openstack_networking_secgroup_v2.cogstack_apps_security_group.name
  ]

  network {
    uuid = data.openstack_networking_network_v2.external_4003.id
  }

  block_device {
    uuid                  = each.value.image_uuid == null ? data.openstack_images_image_v2.ubuntu.id : each.value.image_uuid
    source_type           = "image"
    volume_size           = each.value.volume_size
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }

  connection {
    user        = "ubuntu"
    host        = self.access_ip_v4
    private_key = file(local.ssh_keys.private_key_file)
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait > /tmp/openstack-terraform-remote-exec-provisioner.log || true",
    ]
  }

  lifecycle {
    precondition {
      condition     = (length([for x in var.host_instances : x if x.is_controller == true]) == 1) || var.preexisting_controller_host != null
      error_message = <<-EOT
Invalid variable input. 
Must have exactly one controller host defined in host_instances if preexisting_controller_host is not provided.
Either pass a host with is_controller = true in host_instances, or provide details of an existing host using preexisting_controller_host.

Valid module input to create a controller:
  host_instances = [
    { name = "example-test", is_controller = true },
  ]

  
Valid module input with details of an existing controller:
  host_instances = [
    { name = "example-test"  },
  ]
  preexisting_controller_host = {
    ip_address = "10.1.1.1"
    name = "existing-controller-host"
    unique_name = "WFXGH-existing-controller-host"
  }

Invalid module input:
{
  host_instances = [
    { name = "example-test"  },
  ]
}

	     EOT
    }
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
  part {
    filename     = "cloud-init.yaml"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init.yaml",
      {
        PORTAINER_AGENT_SECRET = var.portainer_secrets.agent_secret
      }
    )
  }
}


data "cloudinit_config" "init_docker_controller" {
  part {
    filename     = "cloud-init-controller.yaml"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init-controller.yaml",
      {
        PORTAINER_AGENT_SECRET   = var.portainer_secrets.agent_secret,
        PORTAINER_ADMIN_PASSWORD = local.portainer_admin_password
      }
    )
  }
}

data "openstack_compute_flavor_v2" "available_compute_flavors" {
  for_each = toset([for vm in var.host_instances : vm.flavour])
  name     = each.value
}


data "openstack_networking_network_v2" "external_4003" {
  name = "external_4003"
}

data "openstack_images_image_v2" "ubuntu" {
  name        = var.ubuntu_immage_name
  most_recent = true
}

