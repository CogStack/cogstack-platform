module "openstack_cogstack_infra" {
  source = "../../../terraform-modules/openstack-kubernetes-k3s"
  host_instances = [
    {
      name          = "cogstack-k3s",
      is_controller = true,
      # floating_ip = {
      #   use_floating_ip = true,
      #   address         = "10.10.10.10"
      # }
    },
    {
      name          = "cogstack-k3s-node-2"
      flavour       = "2cpu4ram"
      volume_size   = 20
      is_controller = false
    },
  ]
  allowed_ingress_ips_cidr = var.allowed_ingress_ips_cidr
  ubuntu_immage_name       = var.ubuntu_immage_name
  # generate_random_name_prefix = false
  # prefix                      = "dev"
  # network = {
  #   network_id = "some-id"
  # }
}
