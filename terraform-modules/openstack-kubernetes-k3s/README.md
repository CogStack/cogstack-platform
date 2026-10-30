# Cogstack Openstack Kubernetes K3S Module

Terraform Module for provisioning VMs on Openstack as a kubernetes cluster using K3s

## Features
- Creates a multi node kuberentes cluster in Openstack with K3s
- VMs will initialise their setup using K3s install scripts
- Setup Networking in Openstack to allow communications between expected services
- Return a KUBECONFIG file for integration with kubernetes and helm providers in terraform

## Prerequisites
- An Openstack Environment able to create Compute and Networking rules
- An accessible Ubuntu image in the openstack environment

<!-- BEGIN_TF_DOCS -->
## Example

This example deploys a two node kubernetes cluster in Openstack with K3s.

```hcl
module "openstack_kubernetes_cluster" {
  source = "../.."

  ubuntu_image_name = "ubuntu-22.04"
  network = {
    name = "public"
  }
  host_instances = [
    { name = "controller", is_controller = true, flavour = "m1.small" },
    { name = "worker", flavour = "m1.small" },
  ]
}
```

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_openstack"></a> [openstack](#requirement\_openstack) | ~> 3.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_cloudinit"></a> [cloudinit](#provider\_cloudinit) | 2.4.1 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.9.1 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.3.2 |
| <a name="provider_openstack"></a> [openstack](#provider\_openstack) | 3.0.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.1 |



## Resources

| Name | Type |
| ---- | ---- |
| [local_file.private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.public_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.copy_kubeconfig](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.kubernetes_nodes_provisioner](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.kubernetes_server_provisioner](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [openstack_compute_instance_v2.kubernetes_nodes](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_instance_v2) | resource |
| [openstack_compute_instance_v2.kubernetes_server](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_instance_v2) | resource |
| [openstack_compute_keypair_v2.compute_keypair](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_keypair_v2) | resource |
| [openstack_networking_floatingip_associate_v2.kubernetes_nodes_fip](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_floatingip_associate_v2) | resource |
| [openstack_networking_floatingip_associate_v2.kubernetes_server_fip](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_floatingip_associate_v2) | resource |
| [openstack_networking_secgroup_rule_v2.cogstack_apps_port_rules](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_rule_v2) | resource |
| [openstack_networking_secgroup_v2.cogstack_apps_security_group](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_v2) | resource |
| [random_id.server](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_password.k3s_token](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [cloudinit_config.init_docker](https://registry.terraform.io/providers/hashicorp/cloudinit/latest/docs/data-sources/config) | data source |
| [cloudinit_config.init_docker_controller](https://registry.terraform.io/providers/hashicorp/cloudinit/latest/docs/data-sources/config) | data source |
| [local_file.kubeconfig_file](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [openstack_compute_flavor_v2.available_compute_flavors](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/data-sources/compute_flavor_v2) | data source |
| [openstack_images_image_v2.ubuntu](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/data-sources/images_image_v2) | data source |
| [openstack_networking_network_v2.network](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/data-sources/networking_network_v2) | data source |
| [openstack_networking_port_v2.nodes_port](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/data-sources/networking_port_v2) | data source |
| [openstack_networking_port_v2.server_port](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/data-sources/networking_port_v2) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_host_instances"></a> [host\_instances](#input\_host\_instances) | Hosts to Create:<br/>name = Human readable hostname for this host. <br/>is\_controller = Must be true for exactly one host. This will run the k3s "server". All other nodes run the k3s "agent".<br/>flavour = The openstack\_compute\_flavor\_v2 for the host<br/>volume\_size = Size in GB for the disk volume for the node<br/>image\_uuid = (Optional) The Openstack image you want to run, to override the default in ubuntu\_image\_name<br/>floating\_ip = (Optional) Floating IP configuration. Set use\_floating\_ip to true and provide address to associate a floating IP with this host | <pre>list(object({<br/>    name          = string,<br/>    flavour       = string,<br/>    volume_size   = optional(number, 20),<br/>    is_controller = optional(bool, false),<br/>    image_uuid    = optional(string, null),<br/>    floating_ip = optional(object({<br/>      use_floating_ip = optional(bool, false) # Using a boolean to make it a plan time value.<br/>      address         = optional(string)<br/>    }), null)<br/>  }))</pre> | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | Network configuration. Either provide 'name' to lookup the network by name, or 'network\_id' to use a network UUID directly. | <pre>object({<br/>    name       = optional(string)<br/>    network_id = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_ubuntu_image_name"></a> [ubuntu\_image\_name](#input\_ubuntu\_image\_name) | Name of an available Machine Image running ubuntu in the openstack environment | `string` | n/a | yes |
| <a name="input_allowed_ingress_ips_cidr"></a> [allowed\_ingress\_ips\_cidr](#input\_allowed\_ingress\_ips\_cidr) | CIDR Block that is allowed ingress to deployed services | `string` | `"0.0.0.0/24"` | no |
| <a name="input_generate_random_name_prefix"></a> [generate\_random\_name\_prefix](#input\_generate\_random\_name\_prefix) | Whether to generate a random prefix for hostnames. If false, hostnames will use only the name from host\_instances | `bool` | `true` | no |
| <a name="input_k3s_version"></a> [k3s\_version](#input\_k3s\_version) | Optional k3s version to install (INSTALL\_K3S\_VERSION), for example v1.32.2+k3s1. When unset, the installer downloads from the stable channel. | `string` | `null` | no |
| <a name="input_output_file_directory"></a> [output\_file\_directory](#input\_output\_file\_directory) | Optional path to write output files to. If directory doesnt exist it will be created | `string` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Optional custom prefix for resource names. If provided will override generate\_random\_name\_prefix | `string` | `null` | no |
| <a name="input_ssh_key_pair"></a> [ssh\_key\_pair](#input\_ssh\_key\_pair) | Paths to an SSH Public and Private Keypair. If provided these will be given SSH access on the created hosts. If not provided, a Keypair will be generated and accessible as a local file | <pre>object({<br/>    public_key_file  = string<br/>    private_key_file = string<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_compute_keypair"></a> [compute\_keypair](#output\_compute\_keypair) | Absolute path to a public and private SSH key pair that is granted login on created VMs |
| <a name="output_created_controller_host"></a> [created\_controller\_host](#output\_created\_controller\_host) | Created Controller Host: A map of { hostname: { data } } |
| <a name="output_created_hosts"></a> [created\_hosts](#output\_created\_hosts) | Created Hosts: A map of { hostname: { data } } |
| <a name="output_created_security_group"></a> [created\_security\_group](#output\_created\_security\_group) | Security group associated to the created hosts |
| <a name="output_kubeconfig_file"></a> [kubeconfig\_file](#output\_kubeconfig\_file) | Path to the generated KUBECONFIG file used to connect to kubernetes |
| <a name="output_kubeconfig_raw"></a> [kubeconfig\_raw](#output\_kubeconfig\_raw) | Kubeconfig for this cluster |

## Existing Network and Floating IPs

You can use this module with a custom OpenStack network by specifying the `network` variable with your own network name or network ID.

Using a custom OpenStack network with your own subnet allows you to improve security by keeping most nodes private. This ensures worker nodes and other internal resources are not directly exposed, reducing security risks. Only the controller node needs a floating IP to be accessible in order to use the k8s api server (eg for kubectl to work from outside the network). Using floating ips will also have the advantage of being stable, so you can destroy/create VMs without having to update anywhere the IP address is referenced by reassigning the floating ip.

To use this configuration, you will probably need to assign a floating IP to the controller node so that it is accessible. You can configure floating IP assignment per node using the `floating_ip` block within each entry in the `host_instances` variable.

Please see this example for using this module with a custom network and floating IPs.

```hcl
module "openstack_kubernetes_cluster" {
  source = "../.."

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
```

When using a non-default network, ensure the controller host has a floating IP so Terraform can access it for provisioning.
<!-- END_TF_DOCS -->
