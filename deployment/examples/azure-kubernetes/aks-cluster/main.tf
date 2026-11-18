
module "naming" {
  source  = "Azure/naming/azurerm"
  version = ">= 0.3.0"
  prefix  = ["cogstack", "terraform"]
}

data "azurerm_location" "this" {
  location = "UK South"
}

resource "azurerm_resource_group" "this" {
  name     = module.naming.resource_group.name
  location = data.azurerm_location.this.location
}

resource "local_file" "kubeconfig_file" {
  content         = module.aks.resource.kube_config_raw
  filename        = "${local.kubeconfig_file}"
  file_permission = "0600"
}
