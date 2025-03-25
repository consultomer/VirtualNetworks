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

data "azurerm_subscription" "current" {}

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

# Virtual Networks
resource "azurerm_virtual_network" "vnets" {
  for_each            = var.vnets
  name                = each.key
  location            = each.value.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = each.value.address_space
}

# Subnets
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

# Network Group for Spokes
resource "azurerm_network_manager_network_group" "spokes" {
  name               = "spokes-group"
  network_manager_id = azurerm_network_manager.AVNM.id
  description        = "Network group for spoke VNETs"
}

resource "azurerm_network_manager_static_member" "spokes" {
  for_each = {
    for vnet_name, vnet in var.vnets : vnet_name => vnet
    if vnet_name != "HubVnet"
  }

  name                      = "spoke-${each.key}"
  network_group_id          = azurerm_network_manager_network_group.spokes.id
  target_virtual_network_id = azurerm_virtual_network.vnets[each.key].id
}

# Hub-Spoke Connectivity Configuration
resource "azurerm_network_manager_connectivity_configuration" "hub_spoke" {
  name                  = "hub-config"
  network_manager_id    = azurerm_network_manager.AVNM.id
  connectivity_topology = "HubAndSpoke"

  applies_to_group {
    network_group_id   = azurerm_network_manager_network_group.spokes.id
    group_connectivity = "DirectlyConnected"
    use_hub_gateway    = true
  }
  hub {
    resource_id   = azurerm_virtual_network.vnets["HubVnet"].id
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

# Public IP for Firewall
resource "azurerm_public_ip" "firewall_pip" {
  name                = "Firewall-PIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Azure Firewall in Hub
resource "azurerm_firewall" "hub_firewall" {
  name                = "HubFirewall"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.subnets["HubVnet-AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.firewall_pip.id
  }
}

# Route Table for Spokes
resource "azurerm_route_table" "spoke_rt" {
  name                = "SpokeRouteTable"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  # Removed invalid attribute disable_bgp_route_propagation

  route {
    name                   = "ToOtherSpokes"
    address_prefix         = "10.0.0.0/8" # Covers all spoke VNets
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub_firewall.ip_configuration[0].private_ip_address
  }
}

# Associate Route Table with Spoke Subnets
resource "azurerm_subnet_route_table_association" "spoke_rt_assoc" {
  for_each = { for k, v in azurerm_subnet.subnets : k => v if length(regexall("subnet1", k)) > 0 }

  subnet_id      = each.value.id
  route_table_id = azurerm_route_table.spoke_rt.id
}

# Network Interfaces
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

# Network Security Groups
resource "azurerm_network_security_group" "nsg" {
  for_each = var.vms

  name                = "nsg-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-InterVNet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/8" # Allow all spoke VNet ranges
    destination_address_prefix = "10.0.0.0/8"
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_association" {
  for_each = var.vms

  network_interface_id      = azurerm_network_interface.nic[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}

# Windows Virtual Machines
resource "azurerm_windows_virtual_machine" "vms" {
  for_each = var.vms

  name                = each.value.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = each.value.location
  size                = "Standard_DS1_v2"

  admin_username = "adminuser"
  admin_password = "P@ssw0rd1234!"

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
