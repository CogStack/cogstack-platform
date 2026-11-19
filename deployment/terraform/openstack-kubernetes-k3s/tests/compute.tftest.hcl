mock_provider "openstack" {
  override_during = plan

  mock_data "openstack_networking_network_v2" {
    defaults = { id = "net-1" }
  }
}

mock_provider "random" {
  override_during = plan

  mock_resource "random_password" {
    defaults = { result = "k3stoken" }
  }

  mock_resource "random_id" {
    defaults = { b64_url = "rand" }
  }
}

override_resource {
  target          = openstack_compute_instance_v2.kubernetes_server
  override_during = plan
  values          = { access_ip_v4 = "10.0.0.1" }
}

run "server_and_node" {
  command = plan

  variables {
    ubuntu_image_name           = "ubuntu"
    generate_random_name_prefix = false
    prefix                      = "test"
    network                     = { name = "public" }
    host_instances = [
      { name = "controller", is_controller = true, flavour = "m1.small" },
      { name = "worker", flavour = "m1.small" },
    ]
  }

  assert {
    condition     = openstack_compute_instance_v2.kubernetes_server.name == "test-controller" && openstack_compute_instance_v2.kubernetes_nodes["worker"].name == "test-worker"
    error_message = "expected a controller and a worker"
  }

  assert {
    condition     = strcontains(data.cloudinit_config.init_docker_controller.part[0].content, "INSTALL_K3S_EXEC=\"server\"")
    error_message = "server cloud-init should install k3s server"
  }

  assert {
    condition     = strcontains(data.cloudinit_config.init_docker["worker"].part[0].content, "K3S_URL=https://10.0.0.1:6443")
    error_message = "node cloud-init should join the server"
  }
}

run "required_only" {
  command = plan

  variables {
    ubuntu_image_name = "ubuntu"
    network           = { name = "public" }
    host_instances = [
      { name = "controller", is_controller = true, flavour = "m1.small" },
      { name = "worker", flavour = "m1.small" },
    ]
  }

  assert {
    condition     = openstack_compute_instance_v2.kubernetes_server.name == "rand-controller" && openstack_compute_instance_v2.kubernetes_nodes["worker"].name == "rand-worker"
    error_message = "required-only should still create a controller and worker"
  }

  assert {
    condition     = openstack_compute_instance_v2.kubernetes_server.block_device[0].volume_size == 20
    error_message = "volume_size should default to 20"
  }

  assert {
    condition     = strcontains(data.cloudinit_config.init_docker["worker"].part[0].content, "K3S_URL=https://10.0.0.1:6443")
    error_message = "node cloud-init should join the server"
  }
}

run "all_variables" {
  command = plan

  variables {
    ubuntu_image_name           = "ubuntu"
    allowed_ingress_ips_cidr    = "10.1.2.0/24"
    k3s_version                 = "v1.32.2+k3s1"
    generate_random_name_prefix = false
    prefix                      = "full"
    output_file_directory       = "/tmp/cogstack-test"
    network = {
      name       = "private"
      network_id = "net-custom"
    }
    ssh_key_pair = {
      private_key_file = "tests/fixtures/fake_key"
      public_key_file  = "tests/fixtures/fake_key.pub"
    }
    host_instances = [
      {
        name          = "controller"
        is_controller = true
        flavour       = "m1.large"
        volume_size   = 50
        image_uuid    = "img-controller"
        floating_ip = {
          use_floating_ip = true
          address         = "203.0.113.10"
        }
      },
      {
        name        = "worker"
        flavour     = "m1.medium"
        volume_size = 40
        image_uuid  = "img-worker"
        floating_ip = {
          use_floating_ip = true
          address         = "203.0.113.11"
        }
      },
    ]
  }

  assert {
    condition     = openstack_compute_instance_v2.kubernetes_server.name == "full-controller" && openstack_compute_instance_v2.kubernetes_nodes["worker"].name == "full-worker"
    error_message = "prefix should be applied to host names"
  }

  assert {
    condition = (
      openstack_compute_instance_v2.kubernetes_server.block_device[0].volume_size == 50 &&
      openstack_compute_instance_v2.kubernetes_server.block_device[0].uuid == "img-controller" &&
      openstack_compute_instance_v2.kubernetes_nodes["worker"].block_device[0].volume_size == 40 &&
      openstack_compute_instance_v2.kubernetes_nodes["worker"].block_device[0].uuid == "img-worker" &&
      openstack_compute_instance_v2.kubernetes_server.network[0].uuid == "net-custom"
    )
    error_message = "optional host and network values should be used"
  }

  assert {
    condition = (
      strcontains(data.cloudinit_config.init_docker_controller.part[0].content, "TF_K3S_VERSION=\"v1.32.2+k3s1\"") &&
      strcontains(data.cloudinit_config.init_docker_controller.part[0].content, "TF_K3S_TLS_SAN=203.0.113.10") &&
      strcontains(data.cloudinit_config.init_docker["worker"].part[0].content, "TF_K3S_NODE_EXTERNAL_IP=203.0.113.11")
    )
    error_message = "cloud-init should include k3s version and floating IPs"
  }

  assert {
    condition = (
      openstack_networking_secgroup_rule_v2.cogstack_apps_port_rules["22-Expose SSH"].remote_ip_prefix == "10.1.2.0/24" &&
      openstack_compute_keypair_v2.compute_keypair.public_key == file("tests/fixtures/fake_key.pub")
    )
    error_message = "ingress CIDR and ssh keypair should be used"
  }
}
