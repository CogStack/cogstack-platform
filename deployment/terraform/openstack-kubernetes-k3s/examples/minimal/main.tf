module "openstack_kubernetes_cluster" {
  source  = "CogStack/kubernetes-k3s/openstack"
  version = "0.1.0"

  ubuntu_image_name = "ubuntu-22.04"
  network = {
    name = "public"
  }
  host_instances = [
    { name = "controller", is_controller = true, flavour = "m1.small" },
    { name = "worker", flavour = "m1.small" },
  ]
}
