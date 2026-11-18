
variable "openstack_environment" {
  type = object({
    openstack_auth_url                      = string,
    openstack_application_credential_secret = string,
    openstack_application_credential_id     = string,
    region                                  = string
  })
  description = <<EOT
openstack_application_credential_id     = OpenStack application credential ID. Scoped to a project
openstack_application_credential_secret = OpenStack application credential secret. Scoped to a project
openstack_auth_url    = OpenStack Auth URL. Scoped accross projects
EOT
}

variable "allowed_ingress_ips_cidr" {
  description = "The CIDR block to grant access to cogstack services to. For example, grant access to internal users in the VPN"
  type        = string
}

variable "ubuntu_immage_name" {
  type        = string
  description = "Name of an available Machine Image running ubuntu in the openstack environment"
}
