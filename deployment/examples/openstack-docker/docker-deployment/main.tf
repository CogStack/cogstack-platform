
module "cogstack_docker_services" {
  source = "github.com/CogStack/cogstack-platform-toolkit//deployment/terraform/modules/cogstack-docker-services?ref=terraform-modules-v0.1.0"
  hosts  = var.hosts
  service_targets = {
    observability  = { hostname = "cogstack-docker-controller" }
    medcat_service = { hostname = "cogstack-docker-medcat-nlp" }
  }
  ssh_private_key_file = var.ssh_private_key_file
}
