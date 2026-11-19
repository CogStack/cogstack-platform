terraform {
  required_providers {
    portainer = {
      source  = "portainer/portainer"
      version = "~> 1.10.0"
    }
    ansible = {
      version = "~> 1.3.0"
      source  = "ansible/ansible"
    }
  }
}


provider "portainer" {
  endpoint        = var.portainer_instance.endpoint
  api_user        = var.portainer_instance.username
  api_password    = var.portainer_instance.password
  skip_ssl_verify = true # optional (default value is `false`)
}
