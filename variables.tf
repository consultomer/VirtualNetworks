
variable "vnets" {
  type = map(object({
    location      = string
    address_space = list(string)
    subnets = map(object({
      name             = string
      address_prefixes = list(string)
    }))
  }))
  default = {
    HubVnet = {
      address_space = ["10.0.0.0/16"]
      location      = "East US"
      subnets = {
        subnet1 = {
          name             = "subnet1"
          address_prefixes = ["10.0.0.0/24"]
        }
      }
    }
    CoreServicesVnet = {
      address_space = ["10.1.0.0/16"]
      location      = "East US"
      subnets = {
        subnet1 = {
          name             = "subnet1"
          address_prefixes = ["10.1.0.0/24"]
        }
      }
    }
    ManufacturingVnet = {
      address_space = ["10.2.0.0/16"]
      location      = "East US"
      subnets = {
        subnet1 = {
          name             = "subnet1"
          address_prefixes = ["10.2.0.0/24"]
        }
      }
    }
    ResearchVnet = {
      address_space = ["10.3.0.0/16"]
      location      = "East US"
      subnets = {
        subnet1 = {
          name             = "subnet1"
          address_prefixes = ["10.3.0.0/24"] # Fixed IP range to be within VNet address space
        }
      }
    }
  }
}

variable "resource_group_name" {
  type    = string
  default = "VirtualNetworks"
}

variable "location" {
  type    = string
  default = "East US"
}


variable "vms" {
  type = map(object({
    name     = string
    location = string
    size     = string
    os_disk = object({
      storage_account_type = string
      disk_size_gb         = number
    })
    network_interface = object({
      name    = string
      primary = bool
    })
    vnet   = string
    subnet = string
  }))
  default = {
    "TestVM1" = {
      name     = "TestVM1"
      location = "East US"
      size     = "Standard_DS1_v2"
      os_disk = {
        storage_account_type = "Standard_LRS"
        disk_size_gb         = 127
      }
      network_interface = {
        name    = "nic-TestVM1"
        primary = true
      }
      vnet   = "CoreServicesVnet"
      subnet = "subnet1"
    }
    "TestVM2" = {
      name     = "TestVM2"
      location = "East US"
      size     = "Standard_DS1_v2"
      os_disk = {
        storage_account_type = "Standard_LRS"
        disk_size_gb         = 127
      }
      network_interface = {
        name    = "nic-TestVM2"
        primary = true
      }
      vnet   = "ManufacturingVnet"
      subnet = "subnet1"
    }
    "TestVM3" = {
      name     = "TestVM3"
      location = "East US"
      size     = "Standard_DS1_v2"
      os_disk = {
        storage_account_type = "Standard_LRS"
        disk_size_gb         = 127
      }
      network_interface = {
        name    = "nic-TestVM3"
        primary = true
      }
      vnet   = "ResearchVnet"
      subnet = "subnet1"
    }
  }
}
