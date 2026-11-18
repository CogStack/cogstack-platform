

locals {
  medcat_ingress_address = module.cogstack_helm_services.service_urls.medcat_service.ip_address
}

output "service_urls" {
  value = {
    medcat_service = {
      example_curl = "curl http://${local.medcat_ingress_address}/${local.services.medcat_service.path_prefix}/api/info"
      example_ui   = "http://${local.medcat_ingress_address}/${local.services.medcat_service.path_prefix}/docs"
    }
  }
  description = "Public URls to call services on"
}


output "dashboard" {
  value = {
    url          = ""
    access_token = kubernetes_secret.admin_user.data.token
  }
  sensitive = true
}