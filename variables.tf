
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
      location      = "West Europe"
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
      location      = "South East Asia"
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