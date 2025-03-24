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
  registration_enabled  = true
}

# Network Interface Resource
resource "azurerm_network_interface" "main" {
  for_each            = var.vms
  name                = each.value.network_interface.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig-${each.key}"
    subnet_id                     = azurerm_subnet.subnets["CoreServicesVnet-subnet1"].id # Using first subnet from CoreServicesVnet
    private_ip_address_allocation = "Dynamic"
    primary                       = each.value.network_interface.primary
  }
}

# Virtual Machine Resource
resource "azurerm_virtual_machine" "Test1" {
  for_each                      = var.vms
  name                          = each.value.name
  location                      = each.value.location
  resource_group_name           = azurerm_resource_group.rg.name
  network_interface_ids         = [azurerm_network_interface.main[each.key].id]
  vm_size                       = each.value.size # Changed from vm_size to match variable name
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${each.value.name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = each.value.os_disk.storage_account_type
    disk_size_gb      = each.value.os_disk.disk_size_gb
  }

  os_profile {
    computer_name  = each.value.name
    admin_username = "adminuser"
    admin_password = "Password1234!" # Note: Consider using a more secure method for credentials
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}