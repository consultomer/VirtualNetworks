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
resource "azurerm_network_interface" "nic" {
  for_each = azurerm_subnet.subnets

  name                = "nic-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vms" {
  for_each = azurerm_network_interface.nic

  name                = "vm-${each.key}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_DS1_v2"

  admin_username = "adminuser"
  admin_password = "P@ssw0rd1234!"

  network_interface_ids = [each.value.id] # Correct way to assign a list of network interface IDs

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  disable_password_authentication = false
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}
