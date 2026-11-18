
locals {
  environments = { for vm_name, vm in var.hosts : vm_name => portainer_environment.portainer_envs[vm_name].id }
}


locals {

  service_urls = {
    grafana        = "http://${var.hosts[var.service_targets.observability.hostname].ip_address}/grafana"
    prometheus     = "http://${var.hosts[var.service_targets.observability.hostname].ip_address}/prometheus"
    medcat_service = "http://${var.hosts[var.service_targets.medcat_service.hostname].ip_address}:5000"
  }

}

locals {
  # Setup config file hashing to trigger restarts when config files change. Requires the env var to also be set in the docker-compose.yml files
  config_files             = fileset("${path.module}/resources/config", "**") # All files
  config_hashes            = [for f in local.config_files : filemd5("${path.module}/resources/config/${f}")]
  hash_of_all_config_files = md5(join("", local.config_hashes)) # One final hash


  # Setup a hash by config folder, allowing a subset of files to be used to trigger restarts on change. Creates a map like { observability = "12d67ff2e637a4aa077c64803afa457d"} 
  config_folders = ["observability"]
  config_files_by_folder = {
    for folder in local.config_folders :
    folder => fileset("${path.module}/resources/config/${folder}", "**")
  }
  config_hashes_by_folder = {
    for folder, files in local.config_files_by_folder :
    folder => md5(join("", [for f in files : filemd5("${path.module}/resources/config/${folder}/${f}")]))
  }

  deployed_config_dir = "/home/ubuntu/cogstack/deployment/config"
}

