# Use Ansible to copy config files to created VMs

resource "terraform_data" "hash_of_all_config_files" {
  input = local.hash_of_all_config_files
}
resource "ansible_playbook" "playbook" {
  for_each   = var.hosts
  playbook   = "${path.module}/ansible/deploy-internal.yml"
  name       = each.value.ip_address
  replayable = false
  lifecycle {
    replace_triggered_by = [terraform_data.hash_of_all_config_files]
    ignore_changes       = [extra_vars]
  }

  extra_vars = {
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = var.ssh_private_key_file
    ansible_host_key_checking    = false
    MEDCAT_SERVICE_HOSTNAME      = var.hosts[var.service_targets.medcat_service.hostname].name
    MEDCAT_SERVICE_IP            = var.hosts[var.service_targets.medcat_service.hostname].ip_address

    OBSERVABILITY_SERVICE_HOSTNAME = var.hosts[var.service_targets.observability.hostname].name
    OBSERVABILITY_SERVICE_IP       = var.hosts[var.service_targets.observability.hostname].ip_address
  }
}

# output "ansible"{
#     value = { for k,v in ansible_playbook.playbook : k => v.ansible_playbook_stdout }
# }
# output "ansible_err"{
#     value ={ for k,v in ansible_playbook.playbook : k => v.ansible_playbook_stderr }
# }
