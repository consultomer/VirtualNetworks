terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "830e9ec2-6cf9-4d0a-a2ac-5a629482dd82"
}

resource "azurerm_resource_group" "rg" {
  name     = "ContosoResourceGroup"
  location = "East US"
}

resource "azurerm_virtual_network" "vnets" {
  for_each            = var.vnets
  name                = each.key
  location            = each.value.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = each.value.address_space
}
# Fixed subnet resource
resource "azurerm_subnet" "subnets" {
  for_each = {
    for subnet in flatten([
      for vnet_name, vnet in var.vnets : [
        for subnet_name, subnet in vnet.subnets : {
          vnet_name        = vnet_name
          subnet_name      = subnet_name
          name             = subnet.name
          address_prefixes = subnet.address_prefixes
        }
      ]
    ]) : "${subnet.vnet_name}-${subnet.subnet_name}" => subnet
  }

  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnets[each.value.vnet_name].name
  address_prefixes     = each.value.address_prefixes
}

resource "azurerm_private_dns_zone" "contoso" {
  name                = "contoso.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "cont" {
  for_each              = var.vnets
  name                  = "${each.key}-link"             # Added suffix for clarity
  resource_group_name   = azurerm_resource_group.rg.name # Fixed to use RG name
  private_dns_zone_name = azurerm_private_dns_zone.contoso.name
  virtual_network_id    = azurerm_virtual_network.vnets[each.key].id # Fixed reference
}