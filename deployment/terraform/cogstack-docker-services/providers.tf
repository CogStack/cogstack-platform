terraform {
  required_providers {
    portainer = {
      source  = "portainer/portainer"
      version = ">= 1.10"
    }
    ansible = {
      version = ">= 1.3"
      source  = "ansible/ansible"
    }
  }
}