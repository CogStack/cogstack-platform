

data "kubernetes_ingress_v1" "created_ingress" {
  # Get the created address of the ingress 
  depends_on = [helm_release.medcat-service]
  metadata {
    name = local.planned_ingress_name
  }
}

locals {
  # https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/ingress_v1#example-usage
  ingress_hostname = data.kubernetes_ingress_v1.created_ingress.status.0.load_balancer.0.ingress.0.hostname
  ingress_ip       = data.kubernetes_ingress_v1.created_ingress.status.0.load_balancer.0.ingress.0.ip
  ingress_address  = local.ingress_hostname != "" ? local.ingress_hostname : local.ingress_ip
}
output "name" {
  value = local.ingress_address
}

check "health_check_medcat_service" {
  # TODO: These checks are dependent on the ingress setup, which may be different. This assumes prefix routing, not hostname
  data "http" "medcat_service" {
    url        = "http://${local.ingress_address}/${local.services.medcat_service.path_prefix}/api/info"
    depends_on = [helm_release.medcat-service]

    # request_headers = {
    #   Host = local.services.medcat_service.hostname
    # }
    retry {
      attempts     = 1
      min_delay_ms = 1000
      max_delay_ms = 60 * 1000
    }
  }

  assert {
    condition     = data.http.medcat_service.status_code == 200
    error_message = "${data.http.medcat_service.url} returned an unhealthy status code"
  }

  assert {
    condition     = jsondecode(data.http.medcat_service.response_body).service_app_name == "MedCAT"
    error_message = "${data.http.medcat_service.url} returned an unexpected response format"
  }
}
check "health_check_medcat_service_path_prefix" {
  data "http" "medcat_service_path_prefix" {
    url        = "http://${local.ingress_address}/${local.services.medcat_service.path_prefix}/docs"
    depends_on = [helm_release.medcat-service]
    retry {
      attempts     = 1
      min_delay_ms = 1000
      max_delay_ms = 60 * 1000
    }
  }

  assert {
    condition     = data.http.medcat_service_path_prefix.status_code == 200
    error_message = "${data.http.medcat_service_path_prefix.url} returned an unhealthy status code"
  }
}
