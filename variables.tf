
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
    CoreServicesVnet = {
      address_space = ["10.20.0.0/16"]
      location      = "East US"
      subnets = {
        subnet1 = {
          name             = "subnet1"
          address_prefixes = ["10.20.0.0/27"]
        }
        subnet2 = {
          name             = "subnet2"
          address_prefixes = ["10.20.10.0/24"]
        }
        subnet3 = {
          name             = "subnet3"
          address_prefixes = ["10.20.20.0/24"]
        }
        subnet4 = {
          name             = "subnet4"
          address_prefixes = ["10.20.30.0/24"]
        }
      }
    }
    ManufacturingVnet = {
      address_space = ["10.30.0.0/16"]
      location      = "East US"
      subnets = {
        subnet1 = {
          name             = "subnet1"
          address_prefixes = ["10.30.10.0/24"]
        }
        subnet2 = {
          name             = "subnet2"
          address_prefixes = ["10.30.20.0/24"]
        }
        subnet3 = {
          name             = "subnet3"
          address_prefixes = ["10.30.21.0/24"]
        }
        subnet4 = {
          name             = "subnet4"
          address_prefixes = ["10.30.22.0/24"]
        }
      }
    }
    ResearchVnet = {
      address_space = ["10.40.0.0/16"]
      location      = "East US"
      subnets = {
        subnet1 = {
          name             = "subnet1"
          address_prefixes = ["10.40.0.0/24"] # Fixed IP range to be within VNet address space
        }
      }
    }
  }
}

variable "resource_group_name" {
  type    = string
  default = "ContosoResourceGroup"
}

variable "location" {
  type    = string
  default = "East US"
}

# Updated variable definition
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
  }))
  default = {
    "TestVM1" = {
      name     = "TestVM1"
      location = "East US"
      vnet     = "CoreServicesVnet"
      subnet   = "subnet1"

    }
    "TestVM2" = {
      name     = "TestVM2"
      location = "East US"
      vnet     = "ManufacturingVnet"
      subnet   = "subnet2"

    }
    "TestVM3" = {
      name     = "TestVM3"
      location = "East US"
      vnet     = "ResearchVnet"
      subnet   = "subnet1"
    }
  }
}