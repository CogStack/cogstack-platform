
locals {
  medcat_service_helm_values = <<EOT
env:
  APP_ROOT_PATH: "/${local.services.medcat_service.path_prefix}"
ingress:
  enabled: true
  http:
    - host: ${local.services.medcat_service.hostname}
      paths:
      - path: /
        pathType: ImplementationSpecific
    - paths:
        - path: /${local.services.medcat_service.path_prefix}
          pathType: ImplementationSpecific
EOT
}
resource "helm_release" "medcat-service" {
  name         = "medcat-service-terraform"
  chart        = "${path.module}/../../deployment/charts/medcat-service-helm"
  timeout      = 600
  atomic       = true
  force_update = true
  values = [
    local.medcat_service_helm_values
    , var.medcat_service_values
  ]
}

data "helm_template" "medcat-service" {
  name    = "medcat-service-terraform"
  chart   = "${path.module}/../../deployment/charts/medcat-service-helm"
  timeout = 600
  atomic  = true

  values = [
    local.medcat_service_helm_values,
    var.medcat_service_values
  ]
}
