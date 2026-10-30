# Cogstack Opesntack K3S Module

Terraform Module for provisioning VMs on Openstack as a kubernetes cluster using K3s

## Features
- Create a multi node kuberentes cluster in Openstack with K3s
- Create VMs and initialise their setup using K3s install scripts
- Setup Networking in Openstack to allow communications between expected services
- Return a KUBECONFIG file for integration with kubernetes and helm providers in terraform

## Requirements
- An Openstack Environment able to create Compute and Networking rules
- An accessible Ubuntu image in the openstack environment

## Example

```hcl
module "openstack_kubernetes_cluster" {
  source = "../../modules/openstack-kubernetes-k3s"
  host_instances = [
    { name = "cogstack-k3s-server", is_controller = true, flavour = "m1.small" },
    { 
      name          = "cogstack-k3s-node-2"
      flavour       = "m1.small"
      volume_size   = 20
      is_controller = false
    },
  ]
  network = {
    name = "public"
  }
  allowed_ingress_ips_cidr = "0.0.0.0/24"
  ubuntu_image_name       = "ubuntu-22.04"
  ssh_key_pair = {
    private_key_file = "~/.ssh/id_rsa",
    public_key_file  = "~/.ssh/id_rsa.pub",
  }
}
```

## Existing Network and Floating IPs
You can use this module with a custom OpenStack network by specifying the `network` variable with your own network name or network ID. 

Using a custom OpenStack network with your own subnet allows you to improve security by keeping most nodes private. This ensures worker nodes and other internal resources are not directly exposed, reducing security risks. Only the controller node needs a floating IP to be accessible in order to use the k8s api server (eg for kubectl to work from outside the network). Using floating ips will also have the advantage of being stable, so you can destroy/create VMs without having to update anywhere the IP address is referenced by reassigning the floating ip. 

To use this configuration, you will probably need to assign a floating IP to the controller node so that it is accessible. You can configure floating IP assignment per node using the `floating_ip` block within each entry in the `host_instances` variable

Please see this example for using thism module with a custom network and floating IPs.

```hcl
host_instances = [
  {
    name = "controller"
    is_controller = true
    flavour = "m1.small"
    floating_ip = {
      use_floating_ip = true
      address         = "203.0.113.10" # Address of an existing floating_ip in openstack
    }
  },
  {
    name = "worker"
    flavour = "m1.small"
    # Optionally also assign a floating IP here, or leave blank to keep it internal to the network   
  }
  network = {
    network_id = openstack_networking_network_v2.example_network.id
  }
]


resource "openstack_networking_network_v2" "example_network" {
  name           = "dev-example-network"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "example_subnet"{
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
```

When using a non-default network, ensure the controller host has a floating IP so Terraform can access it for provisioning.


