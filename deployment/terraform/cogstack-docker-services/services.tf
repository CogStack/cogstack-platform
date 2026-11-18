
resource "portainer_stack" "medcat_service" {
  name        = "medcat-service"
  endpoint_id = local.environments[var.service_targets.medcat_service.hostname]
  stack_file_content = templatefile("${path.module}/resources/medcat-service.docker-compose.yml",
    {
      ENVIRONMENT_VARIABLES = yamlencode(var.service_targets.medcat_service.environment_variables)
  })
  deployment_type = "standalone"
  method          = "string"
  pull_image      = true
  prune           = true
}

