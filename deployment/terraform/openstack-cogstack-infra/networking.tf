

locals {
  devops_controller_cidr = "${local.controller_host_instance.ip_address}/32"

  cogstack_apps_ingress_rules = [
    { port = 22, cidr = var.allowed_ingress_ips_cidr, description = "SSH" },
    { port = 9443, cidr = var.allowed_ingress_ips_cidr, description = "Allow access to Portainer UI to users" },
    { port = 80, cidr = var.allowed_ingress_ips_cidr, description = "Expose traefik to users on port 80" },
    { port = 5000, cidr = var.allowed_ingress_ips_cidr, description = "MedCAT Service API for allowed users" },
  ]
  cogstack_apps_devops_controller_rules = [
    { port = 9001, cidr = local.devops_controller_cidr, description = "Allow ingress to portainer agent from the devops controller" },
    { port = 5000, cidr = local.devops_controller_cidr, description = "MedCAT Service API for Probing" },
  ]
  cogstack_apps_ingress_rules_map           = { for rule in local.cogstack_apps_ingress_rules : "${rule.port}-${rule.description}" => rule }
  cogstack_apps_devops_controller_rules_map = { for rule in local.cogstack_apps_devops_controller_rules : "${rule.port}-${rule.description}" => rule }

  user_provided_security_rules_map = { for rule in var.allowed_security_group_rules : "${rule.port}-${rule.description}" => rule }
}

resource "openstack_networking_secgroup_v2" "cogstack_apps_security_group" {
  name        = "${local.random_prefix}-cogstack-services"
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
resource "openstack_networking_secgroup_rule_v2" "cogstack_apps_devops_controller_rules" {
  for_each          = local.cogstack_apps_devops_controller_rules_map
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value.port
  port_range_max    = each.value.port
  remote_ip_prefix  = each.value.cidr
  description       = each.value.description
  security_group_id = openstack_networking_secgroup_v2.cogstack_apps_security_group.id
}

resource "openstack_networking_secgroup_rule_v2" "user_provided_security_rules_map" {
  for_each          = local.user_provided_security_rules_map
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value.port
  port_range_max    = each.value.port
  remote_ip_prefix  = each.value.cidr
  description       = each.value.description
  security_group_id = openstack_networking_secgroup_v2.cogstack_apps_security_group.id
}
