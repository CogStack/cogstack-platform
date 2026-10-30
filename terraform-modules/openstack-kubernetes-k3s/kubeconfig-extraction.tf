resource "null_resource" "copy_kubeconfig" {
  depends_on = [openstack_compute_instance_v2.kubernetes_server, null_resource.kubernetes_server_provisioner]

  # Re-fetch kubeconfig whenever the controller is replaced (new cluster CA/certs).
  triggers = {
    server_id  = openstack_compute_instance_v2.kubernetes_server.id
    ip_address = local.controller_host_instance.ip_address
  }

  provisioner "local-exec" {
    # Copy the kubeconfig file from the host to a local file using SCP.
    # Use ssh-keyscan to prevent interactive prompt on unknown host
    # Use sed to replace the localhost address in the KUBECONFIG file with the actual IP adddress of the created VM.
    command = <<EOT
mkdir -p ${path.root}/.build/ && \
ssh-keyscan -H ${local.controller_host_instance.ip_address} >> ${path.root}/.build/.known_hosts_cogstack && \
ssh -o UserKnownHostsFile=${path.root}/.build/.known_hosts_cogstack -o StrictHostKeyChecking=yes \
    -i ${local.ssh_keys.private_key_file} \
    ubuntu@${local.controller_host_instance.ip_address} \
    "sudo cat /etc/rancher/k3s/k3s.yaml" > ${local.kubeconfig_file} && \
sed -i "s/127.0.0.1/${local.controller_host_instance.ip_address}/" ${local.kubeconfig_file}
EOT
  }
}

data "local_file" "kubeconfig_file" {
  filename   = local.kubeconfig_file
  depends_on = [null_resource.copy_kubeconfig]
}
output "kubeconfig_raw" {
  value       = data.local_file.kubeconfig_file.content
  description = "Kubeconfig for this cluster"
}
