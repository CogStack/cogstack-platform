

module "aks" {
  # Using the Azure Verified Module AKS Dev/Test module
  # This is not recommended by Azure to be used for production deployments

  # As of 26th 11 2025, the official module has a fatal bug on https://github.com/Azure/terraform-azurerm-avm-ptn-aks-dev/issues/55
  # This error is fixed in this PR, switch back to the official module path when it's merged in 
  # https://github.com/Azure/terraform-azurerm-avm-ptn-aks-dev/pull/42
  # For now use the fork for that PR:
  source              = "github.com/pauldotyu/terraform-azurerm-avm-ptn-aks-dev"

  # source              = "Azure/avm-ptn-aks-dev/azurerm"
  # version             = "0.2.0"
  name                = module.naming.kubernetes_cluster.name_unique
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  kubernetes_version  = "1.35" # Set the k8s version to latest as of February 2026. This is to get the nodes running Ubuntu 24.04 and solve vm.max_map_count issue
}

# Alternative - use the Azure Verified Module AKS Production Module
# This is their recommended guidance for prod deployments. This requires more account permissions
#
# Datasource of current tenant ID
# data "azurerm_client_config" "current" {}
#
# module "avm-ptn-aks-production"  { 
#   source  = "Azure/avm-ptn-aks-production/azurerm" 
#   version = "0.5.0" 
#   location = azurerm_resource_group.this.location
#   name =  module.naming.kubernetes_cluster.name
#   network = {
#     node_subnet_id = module.avm_res_network_virtualnetwork.subnets["subnet"].resource_id
#     pod_cidr       = "192.168.0.0/16"
#     service_cidr   = "10.2.0.0/16"
#   }
#   resource_group_name = azurerm_resource_group.this.name
#   rbac_aad_tenant_id          = data.azurerm_client_config.current.tenant_id

# }

# module "avm_res_network_virtualnetwork" {
#   source  = "Azure/avm-res-network-virtualnetwork/azurerm"
#   version = "0.7.1"

#   address_space       = ["10.31.0.0/16"]
#   location            = azurerm_resource_group.this.location
#   name                = module.naming.virtual_network.name
#   resource_group_name = azurerm_resource_group.this.name
#   subnets = {
#     "subnet" = {
#       name             = "nodecidr"
#       address_prefixes = ["10.31.0.0/17"]
#     }
#     "private_link_subnet" = {
#       name             = "private_link_subnet"
#       address_prefixes = ["10.31.129.0/24"]
#     }
#   }
# }
