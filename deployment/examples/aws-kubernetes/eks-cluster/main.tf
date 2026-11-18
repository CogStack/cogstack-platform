
resource "null_resource" "copy_kubeconfig" {
  depends_on = [module.eks, module.vpc]

  provisioner "local-exec" {
    # Extract the kubeconfig file using the AWS CLI. Save it as a local file 
    command = <<EOT
aws eks update-kubeconfig --name ${module.eks.cluster_name} --kubeconfig ${local.kubeconfig_file}
EOT
  }
}
