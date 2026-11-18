terraform {
  required_providers {
    helm = {
      version = "~> 3"
      source  = "hashicorp/helm"
    }
    kubernetes = {
      version = "~> 2"
      source  = "hashicorp/kubernetes"
    }
  }
}
