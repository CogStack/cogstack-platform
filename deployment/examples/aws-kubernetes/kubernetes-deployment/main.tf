resource "helm_release" "cogstack-ce" {
  name         = "cogstack"
  chart        = "oci://registry-1.docker.io/cogstacksystems/cogstack-ce-helm"
  version      = "0.6.0"
  timeout      = 600
  atomic       = true
  render_subchart_notes = false
  values = [ <<EOT
    opensearch:
      replicas: 1
    EOT
  ]
}

provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_file
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_file
}

variable "kubeconfig_file" {
  description = "Path to the generated KUBECONFIG file used to connect to kubernetes"
}

output "cogstack_notes" {
  value = helm_release.cogstack-ce.metadata.notes
}