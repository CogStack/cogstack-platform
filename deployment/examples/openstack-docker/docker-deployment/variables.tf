# Variables for Docker Deployment
# It's recommended to follow the README.md and use the output of the openstack-vms module

variable "portainer_instance" {
  type = object({
    endpoint = string
    username = string
    password = string
  })

  description = <<EOT
endpoint = API to call portainer on
username        = Portainer username
password        = Portainer password to use
EOT
}

variable "ssh_private_key_file" {
  type        = string
  description = "A filepath to a SSH Private key that is used to SSH login to created hosts"
}

variable "hosts" {
  type = map(object({
    ip_address  = string,
    unique_name = string,
    name        = string
  }))
  description = "Created Hosts: A map of { hostname: { data } }"
}
