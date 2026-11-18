

resource "portainer_environment" "portainer_envs" {
  depends_on          = [ansible_playbook.playbook] # Add dependency to await the service 
  for_each            = var.hosts
  name                = each.key
  environment_address = "tcp://${each.value.ip_address}:9001"
  type                = 2

}
