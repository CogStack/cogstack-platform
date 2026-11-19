

locals {
  devops_controller_cidr = "${local.controller_host_instance.ip_address}/32"

  cogstack_apps_ingress_rules = [
    { port = 22, cidr = var.allowed_ingress_ips_cidr, description = "Expose SSH" },
    { port = 80, cidr = var.allowed_ingress_ips_cidr, description = "Expose port 80 (hhtp) for ingress" },
    { port = 443, cidr = var.allowed_ingress_ips_cidr, description = "Expose port 443 (https) for ingress" },
    { port = 6443, cidr = var.allowed_ingress_ips_cidr, description = "Expose kubernetes for CLI" }
  ]
  cogstack_apps_ingress_rules_map = { for rule in local.cogstack_apps_ingress_rules : "${rule.port}-${rule.description}" => rule }
}

resource "openstack_networking_secgroup_v2" "cogstack_apps_security_group" {
  name        = local.prefix != "" ? "${local.prefix}-cogstack-services" : "cogstack-services"
  description = "Cogstack Apps and Services Group"
}

resource "openstack_networking_secgroup_rule_v2" "cogstack_apps_port_rules" {
  for_each          = local.cogstack_apps_ingress_rules_map
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value.port
  port_range_max    = each.value.port
  remote_ip_prefix  = each.value.cidr
  description       = each.value.description
  security_group_id = openstack_networking_secgroup_v2.cogstack_apps_security_group.id
}



# Look up ports by device_id and network_id
data "openstack_networking_port_v2" "server_port" {
  count      = local.controller_host_has_floating_ip ? 1 : 0
  device_id  = openstack_compute_instance_v2.kubernetes_server.id
  network_id = openstack_compute_instance_v2.kubernetes_server.network[0].uuid
}

data "openstack_networking_port_v2" "nodes_port" {
  for_each   = { for vm in var.host_instances : vm.name => vm if !vm.is_controller && vm.floating_ip != null && vm.floating_ip.use_floating_ip }
  device_id  = openstack_compute_instance_v2.kubernetes_nodes[each.key].id
  network_id = openstack_compute_instance_v2.kubernetes_nodes[each.key].network[0].uuid
}

# Associate floating IP with kubernetes server
resource "openstack_networking_floatingip_associate_v2" "kubernetes_server_fip" {
  count       = local.controller_host_has_floating_ip ? 1 : 0
  floating_ip = local.controller_host.floating_ip.address
  port_id     = data.openstack_networking_port_v2.server_port[0].id
}

# Associate floating IPs with kubernetes nodes
resource "openstack_networking_floatingip_associate_v2" "kubernetes_nodes_fip" {
  for_each    = { for vm in var.host_instances : vm.name => vm if !vm.is_controller && vm.floating_ip != null && vm.floating_ip.use_floating_ip }
  floating_ip = each.value.floating_ip.address
  port_id     = data.openstack_networking_port_v2.nodes_port[each.key].id
}
