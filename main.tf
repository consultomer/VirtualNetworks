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

data "azurerm_subscription" "current" {
}

resource "azurerm_resource_group" "rg" {
  name     = "ContosoResourceGroup"
  location = "East US"
}

resource "azurerm_network_manager" "AVNM" {
  name                = "avnm-network-manager"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  scope {
    subscription_ids = [data.azurerm_subscription.current.id]
  }
  scope_accesses = ["Connectivity"]
  description    = "example network manager"
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
# Define Network Group for Spokes
resource "azurerm_network_manager_network_group" "spokes" {
  name               = "spokes-group"
  network_manager_id = azurerm_network_manager.AVNM.id
  description        = "Network group for spoke VNETs"
}

resource "azurerm_network_manager_static_member" "spokes" {
  for_each = {
    for vnet_name, vnet in var.vnets : vnet_name => vnet
    if vnet_name != "ResearchVnet" # Exclude hub VNET
  }

  name                      = "spoke-${each.key}"
  network_group_id          = azurerm_network_manager_network_group.spokes.id
  target_virtual_network_id = azurerm_virtual_network.vnets[each.key].id
}

# Define Hub-Spoke Connectivity Configuration
resource "azurerm_network_manager_connectivity_configuration" "hub_spoke" {
  name                  = "hub-spoke-config"
  network_manager_id    = azurerm_network_manager.AVNM.id
  connectivity_topology = "HubAndSpoke"

  applies_to_group {
    group_connectivity = "None"
    network_group_id   = azurerm_network_manager_network_group.spokes.id
  }

  hub {
    resource_id   = azurerm_virtual_network.vnets["ResearchVnet"].id
    resource_type = "Microsoft.Network/virtualNetworks"
  }
}

# Deploy Network Manager Configuration
resource "azurerm_network_manager_deployment" "example" {
  network_manager_id = azurerm_network_manager.AVNM.id
  location           = "eastus"
  scope_access       = "Connectivity"
  configuration_ids  = [azurerm_network_manager_connectivity_configuration.hub_spoke.id]
}

# Create network interfaces for VMs
resource "azurerm_network_interface" "nic" {
  for_each = var.vms

  name                = "nic-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets["${each.value.vnet}-${each.value.subnet}"].id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create Windows Virtual Machines
resource "azurerm_windows_virtual_machine" "vms" {
  for_each = var.vms

  name                = each.value.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = each.value.location
  size                = "Standard_DS1_v2" # Change if needed

  admin_username = "adminuser"
  admin_password = "P@ssw0rd1234!" # Use a secure password or Vault

  network_interface_ids = [azurerm_network_interface.nic[each.key].id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 127
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}
