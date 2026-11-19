
output "service_urls" {
  value = {
    medcat_service = {
      ip_address   = local.ingress_address
      hostname     = local.services.medcat_service.hostname
      example_curl = "curl -H 'Host: ${local.services.medcat_service.hostname}' http://${local.ingress_address}/api/info"
      example_ui   = "http://${local.ingress_address}/${local.services.medcat_service.path_prefix}/docs"
    }
  }
  description = "Public URls to call services on "
}

output "medcat_service_helm_chart" {
  value       = data.helm_template.medcat-service.manifests
  description = "Deployed helm template"
}