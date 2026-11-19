
check "health_check" {
  data "http" "medcat_service" {
    url        = "${local.service_urls.medcat_service}/api/info"
    depends_on = [portainer_stack.medcat_service]
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