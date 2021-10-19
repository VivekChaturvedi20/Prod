data "azurerm_subnet" "devOpssubnet" {
  name = "subnet_01"
  resource_group_name = "KFDevOps"
  virtual_network_name = "KFDevOpsVnet"
}
data "azurerm_virtual_network" "devOpsVnet" {
  name = "KFDevOpsVnet"
  resource_group_name = "KFDevOps"
}
data "azurerm_private_dns_zone" "devopsDNSZone" {
  name = "privatelink.azurecr.io"
  resource_group_name = "KFDevOps"
}
provider "azurerm" {
  features {}
}
output "devopVnetID" {
  value = data.azurerm_virtual_network.devOpsVnet.id
}
output "devopsSubnetID" {
  value = data.azurerm_subnet.devOpssubnet.id
}
output "devopsDNSZoneID" {
  value = data.azurerm_private_dns_zone.devopsDNSZone.id
}