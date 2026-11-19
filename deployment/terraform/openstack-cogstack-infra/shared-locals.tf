
locals {
  random_prefix         = random_id.server.b64_url
  output_file_directory = var.output_file_directory != null ? var.output_file_directory : "${path.root}/.build"
}


locals {
  # Desired controller host
  controller_host = var.preexisting_controller_host != null ? var.preexisting_controller_host : one([for host in var.host_instances : host if host.is_controller])

  # Created controller host instance
  created_controller_host = var.preexisting_controller_host != null ? null : openstack_compute_instance_v2.cogstack_ops_compute[local.controller_host.name]

  # Final controller host instance (either created or preexisting)
  controller_host_instance = {
    name        = local.controller_host.name
    ip_address  = var.preexisting_controller_host != null ? var.preexisting_controller_host.ip_address : local.created_controller_host.access_ip_v4
    unique_name = var.preexisting_controller_host != null && var.preexisting_controller_host.unique_name != null ? var.preexisting_controller_host.unique_name : local.created_controller_host.name
  }
}

resource "random_id" "server" {
  keepers = {
    # Generate a new id each time we recreate the hosts
    cloud_init_config            = data.cloudinit_config.init_docker.id
    cloud_init_config_controller = data.cloudinit_config.init_docker_controller.id
  }

  byte_length = 4
}

resource "random_password" "portainer_password" {
  count  = (var.portainer_secrets.admin_password == null) && (var.preexisting_controller_host == null) ? 1 : 0
  length = 16
}
locals {

  # Nested ternary for portainer password:
  # admin_password	preexisting_host	 Result
  # notnull	        any	               provided password
  # null	          not null	         "unknown"
  # null	          null	             generated password
  portainer_admin_password = (
    var.portainer_secrets.admin_password != null ? var.portainer_secrets.admin_password :
    var.preexisting_controller_host != null ? "unknown" :
    random_password.portainer_password[0].result
  )
}
