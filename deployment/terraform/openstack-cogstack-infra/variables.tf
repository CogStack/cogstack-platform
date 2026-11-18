variable "portainer_secrets" {
  type = object({
    agent_secret   = optional(string, "portainer_agent_secret")
    admin_password = optional(string, null),
  })
  default = {
  }
  description = <<EOT
agent_secret = Portainer agent secret for connection to portainer
admin_password = Optional Portainer password to create admin account with. If not supplied one will be generated.
EOT
}

variable "allowed_ingress_ips_cidr" {
  type        = string
  description = "CIDR Block that is allowed ingress to deployed services"
}

variable "ubuntu_immage_name" {
  type        = string
  description = "Name of an available Machine Image running ubuntu in the openstack environment"

}

variable "host_instances" {
  description = <<EOT
Hosts to Create:
name = Human readable hostname for this host. 
is_controller = Must be true for exactly one host. This will run the portainer "controller". All other nodes run the portainer "agent".
flavour = The openstack_compute_flavor_v2 for the host
volume_size = Size in GB for the disk volume for the node
image_uuid = (Optional) The Openstack image you want to run, to override the default in ubuntu_immage_name
EOT
  type = list(object({
    name          = string,
    flavour       = optional(string, "2cpu4ram"),
    volume_size   = optional(number, 20),
    is_controller = optional(bool, false),
    image_uuid    = optional(string, null)
  }))

  default = [
    { name = "cogstack-devops", is_controller = true }
  ]
  validation {
    condition     = length(var.host_instances) >= 1
    error_message = "Must have at least one host instance"
  }

  validation {
    condition     = length([for x in var.host_instances : x if x.is_controller == true]) <= 1
    error_message = "Must have at most 1 controller host"
  }

}

variable "preexisting_controller_host" {
  type = object({
    name        = string,
    ip_address  = string,
    unique_name = optional(string)
  })
  default     = null
  description = <<EOT
Optionally provide details of an existing host to use as the controller host for Portainer

name        = Human readable hostname for this host,
ip_address  = IP Address of the existing controller host,
unique_name = optional(string)
EOT
}

variable "allowed_security_group_rules" {
  type = list(object({
    port        = number
    cidr        = string
    description = string
  }))
  default     = []
  description = <<EOT
Optionally provide additional security group rules to allow ingress to the created hosts

port = Port number to allow ingress to
cidr = CIDR block to allow ingress from
description = Description for the rule
EOT 
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