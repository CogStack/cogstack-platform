terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0.0"
    }
  }
}

provider "openstack" {
  insecure                      = true
  enable_logging                = true
  auth_url                      = var.openstack_environment.openstack_auth_url
  application_credential_id     = var.openstack_environment.openstack_application_credential_id
  application_credential_secret = var.openstack_environment.openstack_application_credential_secret
  region                        = var.openstack_environment.region
}

