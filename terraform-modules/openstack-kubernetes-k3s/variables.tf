variable "allowed_ingress_ips_cidr" {
  type        = string
  default     = "0.0.0.0/24"
  description = "CIDR Block that is allowed ingress to deployed services"
}

variable "ubuntu_immage_name" {
  type        = string
  description = "Name of an available Machine Image running ubuntu in the openstack environment"
}

variable "k3s_version" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional k3s version to install (INSTALL_K3S_VERSION), for example v1.32.2+k3s1. When unset, the installer downloads from the stable channel."
}

variable "host_instances" {
  description = <<EOT
Hosts to Create:
name = Human readable hostname for this host. 
is_controller = Must be true for exactly one host. This will run the k3s "server". All other nodes run the k3s "agent".
flavour = The openstack_compute_flavor_v2 for the host
volume_size = Size in GB for the disk volume for the node
image_uuid = (Optional) The Openstack image you want to run, to override the default in ubuntu_immage_name
floating_ip = (Optional) Floating IP configuration. Set use_floating_ip to true and provide address to associate a floating IP with this host
EOT
  type = list(object({
    name          = string,
    flavour       = string,
    volume_size   = optional(number, 20),
    is_controller = optional(bool, false),
    image_uuid    = optional(string, null),
    floating_ip = optional(object({
      use_floating_ip = optional(bool, false) # Using a boolean to make it a plan time value.
      address         = optional(string)
    }), null)
  }))

  validation {
    condition     = length(var.host_instances) >= 1
    error_message = "Must have at least one host instance"
  }

  validation {
    condition     = length([for x in var.host_instances : x if x.is_controller == true]) == 1
    error_message = "Must have exactly one controller host"
  }

}

variable "ssh_key_pair" {
  type = object({
    public_key_file  = string
    private_key_file = string
  })
  default     = null
  description = "Paths to an SSH Public and Private Keypair. If provided these will be given SSH access on the created hosts. If not provided, a Keypair will be generated and accessible as a local file"
  validation {
    condition     = var.ssh_key_pair == null || fileexists(var.ssh_key_pair.private_key_file)
    error_message = "No file exists in SSH private key path"
  }
  validation {
    condition     = var.ssh_key_pair == null || fileexists(var.ssh_key_pair.public_key_file)
    error_message = "No file exists in SSH public key path"
  }
}

variable "output_file_directory" {
  type        = string
  default     = null
  description = "Optional path to write output files to. If directory doesnt exist it will be created"
}

variable "generate_random_name_prefix" {
  type        = bool
  default     = true
  description = "Whether to generate a random prefix for hostnames. If false, hostnames will use only the name from host_instances"
}

variable "prefix" {
  type        = string
  default     = null
  description = "Optional custom prefix for resource names. If provided will override generate_random_name_prefix"
}

variable "network" {
  type = object({
    name       = optional(string)
    network_id = optional(string)
  })
  description = "Network configuration. Either provide 'name' to lookup the network by name, or 'network_id' to use a network UUID directly."
  validation {
    condition     = var.network.name != null || var.network.network_id != null
    error_message = "Either network.name or network.network_id must be provided"
  }
}

check "controller_floating_ip_required_when_using_floating_ips" {
  assert {
    condition = (
      length([for host in var.host_instances : host if host.floating_ip != null && host.floating_ip.use_floating_ip == true]) == 0
      || length([for host in var.host_instances : host if host.is_controller == true && host.floating_ip != null && host.floating_ip.use_floating_ip == true]) == 1
    )
    error_message = <<-EOT
When using floating IPs, the controller host should have a floating IP in order to be accessible by the terraform agent
EOT
  }
}

