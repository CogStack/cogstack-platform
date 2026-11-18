provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_file
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_file
}

locals {
  services = {
    medcat_service = {
      path_prefix = "medcat-service"
    }
  }
}

module "cogstack_helm_services" {
  source                = "github.com/CogStack/cogstack-platform-toolkit//deployment/terraform/modules/cogstack-helm-services?ref=terraform-modules-v0.1.0"
  medcat_service_values = <<EOT
replicaCount: 2
EOT
}