resource "portainer_stack" "observability_stack" {
  name            = "cogstack-observability"
  deployment_type = "standalone"
  method          = "string"
  endpoint_id     = local.environments[var.service_targets.observability.hostname]
  pull_image      = true

  stack_file_content = file("${path.module}/resources/config/observability/observability.docker-compose.yml")
  prune              = true
  env {
    name  = "BASE_DIR"
    value = local.deployed_config_dir
  }
  env {
    name  = "CONFIG_HASH"
    value = local.config_hashes_by_folder["observability"]
  }
  env {
    name  = "ALLOY_HOSTNAME"
    value = var.service_targets.observability.hostname
  }
  env {
    name  = "ALLOY_IP_ADDRESS"
    value = var.hosts[var.service_targets.observability.hostname].ip_address
  }
}

locals {
  prometheus_url = "http://${var.hosts[var.service_targets.observability.hostname].ip_address}/prometheus"
}
resource "portainer_stack" "observability_exporters_stack" {
  for_each = { for k, v in var.hosts : k => v if !contains([var.service_targets.observability.hostname], v.name) }

  name               = "cogstack-observability-exporters"
  deployment_type    = "standalone"
  method             = "string"
  endpoint_id        = local.environments[each.value.name]
  pull_image         = true
  prune              = true
  stack_file_content = file("${path.module}/resources/config/observability/exporters.docker-compose.yml")

  env {
    name  = "PROMETHEUS_URL"
    value = local.prometheus_url
  }
  env {
    name  = "ALLOY_HOSTNAME"
    value = each.value.name
  }
  env {
    name  = "ALLOY_IP_ADDRESS"
    value = each.value.ip_address
  }
}
