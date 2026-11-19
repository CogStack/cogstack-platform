module "openstack_kubernetes_cluster" {
  source  = "CogStack/kubernetes-k3s/openstack"
  version = "0.1.0"

  ubuntu_image_name = "ubuntu-22.04"
  network = {
    network_id = openstack_networking_network_v2.example_network.id
  }
  host_instances = [
    {
      name          = "controller"
      is_controller = true
      flavour       = "m1.small"
      floating_ip = {
        use_floating_ip = true
        address         = "203.0.113.10" # Address of an existing floating_ip in openstack
      }
    },
    {
      name    = "worker"
      flavour = "m1.small"
      # Optionally also assign a floating IP here, or leave blank to keep it internal to the network
    },
  ]
}

resource "openstack_networking_network_v2" "example_network" {
  name           = "dev-example-network"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "example_subnet" {
  name       = "dev-example-subnet"
  network_id = openstack_networking_network_v2.example_network.id
  cidr       = "192.168.0.0/24"
  ip_version = 4
}

resource "openstack_networking_router_v2" "example_router" {
  name                = "test-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.public.id
}

data "openstack_networking_network_v2" "public" {
  name = "public"
}
