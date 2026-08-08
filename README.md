# VirtualNetworks

Terraform module that deploys a hub-and-spoke network topology on Microsoft Azure, wired together with Azure Virtual Network Manager (AVNM). It provisions a hub VNet with a VPN gateway, a set of spoke VNets, a network group that auto-enrolls every spoke, and sample Windows VMs connected across the topology — all driven by a single `for_each`-based configuration.

## Features

- **Hub-and-spoke topology** managed centrally through Azure Virtual Network Manager
- **Dynamic VNet & subnet creation** from a single `vnets` map variable — add a network by editing one variable, no new resource blocks
- **Automatic spoke enrollment** — every VNet except the hub is added to an AVNM network group and connected via a `HubAndSpoke` connectivity configuration
- **Site-to-site ready hub** — a `RouteBased` VPN Gateway and Gateway Subnet are provisioned on the hub VNet
- **Sample Windows VMs** deployed into their target VNet/subnet with a dedicated NIC and NSG (RDP allowed) per VM
- **Remote state** stored in an Azure Storage account backend
- **CI/CD included** — a GitHub Actions workflow formats, plans, and applies the configuration on every push to `main`

## Architecture

```
                     Azure Virtual Network Manager
                              (Connectivity)
                                    │
                     ┌──────────────┴──────────────┐
                     │        HubVnet (Hub)         │
                     │  VPN Gateway + GatewaySubnet  │
                     └──────────────┬──────────────┘
              ┌──────────────────────┼──────────────────────┐
    ┌─────────┴─────────┐  ┌─────────┴─────────┐  ┌─────────┴─────────┐
    │ CoreServicesVnet   │  │ ManufacturingVnet  │  │  ResearchVnet     │
    │  (spoke, TestVM1)  │  │  (spoke, TestVM2)  │  │  (spoke, TestVM3) │
    └────────────────────┘  └────────────────────┘  └───────────────────┘
```

## Technologies Used

- [Terraform](https://www.terraform.io/) (>= required by the `azurerm` provider)
- [azurerm provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest) `>= 4.0`
- Azure Virtual Network Manager, Virtual Network, VPN Gateway, Network Security Group, Windows Virtual Machine
- GitHub Actions for CI/CD (`hashicorp/setup-terraform`, `azure/login`)

## Prerequisites

- [Terraform CLI](https://developer.hashicorp.com/terraform/install)
- An Azure subscription and the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az login`) or a service principal for CI
- An existing Azure Storage account for the Terraform backend (see `terraform.tf`)

## Configuration

### Backend

Remote state is configured in [`terraform.tf`](terraform.tf) against an Azure Storage account. Update the `resource_group_name`, `storage_account_name`, and `container_name` to match your own storage account before running `terraform init`.

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "TestingTerraform"
    storage_account_name = "terraform7172"
    container_name       = "collectorstate"
    key                  = "vnetterraform.tfstate"
  }
}
```

### Variables

All infrastructure is driven by the variables in [`variables.tf`](variables.tf):

| Variable              | Description                                                       | Default              |
| --------------------- | ------------------------------------------------------------------ | --------------------- |
| `resource_group_name` | Name of the resource group that holds every resource               | `VirtualNetworks`     |
| `location`            | Default Azure region for the resource group                        | `East US`             |
| `vnets`                | Map of VNets, each with an address space and its own subnets map   | `HubVnet`, `CoreServicesVnet`, `ManufacturingVnet`, `ResearchVnet` |
| `vms`                  | Map of Windows VMs, each pinned to a target `vnet`/`subnet`        | `TestVM1`, `TestVM2`, `TestVM3` |

Add a new spoke network by adding an entry to `vnets`; add a new VM by adding an entry to `vms` and pointing it at an existing `vnet`/`subnet`. Everything else (subnet creation, spoke enrollment, NIC/NSG wiring) is generated automatically.

> **Note:** The sample VM admin credentials in `main.tf` are placeholders for demo purposes. Replace `admin_password` with a value from Key Vault or a secure variable before deploying anywhere near production.

## Usage

```bash
# Authenticate to Azure
az login

# Initialize Terraform and the remote backend
terraform init

# Review the plan
terraform plan

# Apply
terraform apply
```

### CI/CD

[`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) runs on every push to `main`:

1. Checks out the repository
2. Sets up Terraform
3. Authenticates to Azure via `azure/login` using the `AZURE_CREDENTIALS` secret
4. Runs `terraform fmt -check`, `terraform plan`, and `terraform apply -auto-approve`

To use it, add an `AZURE_CREDENTIALS` secret (a service principal JSON, or configure OIDC) in your repository settings.

## Resources Created

| Resource                                             | Purpose                                            |
| ----------------------------------------------------- | --------------------------------------------------- |
| `azurerm_resource_group`                              | Container for all resources                        |
| `azurerm_network_manager`                             | Central connectivity & security-admin configuration |
| `azurerm_virtual_network` (× N)                       | Hub and spoke VNets                                 |
| `azurerm_subnet` (× N)                                | Subnets defined per VNet                            |
| `azurerm_network_manager_network_group`               | Group of all spoke VNets                            |
| `azurerm_network_manager_static_member` (× N)         | Enrolls each spoke into the network group           |
| `azurerm_network_manager_connectivity_configuration`  | Hub-and-spoke connectivity topology                 |
| `azurerm_network_manager_deployment`                  | Deploys the connectivity configuration              |
| `azurerm_public_ip` / `azurerm_virtual_network_gateway` | Site-to-site VPN gateway on the hub                |
| `azurerm_network_interface` (× N)                     | One NIC per VM                                      |
| `azurerm_network_security_group` (× N)                | RDP (3389) allowed per VM                            |
| `azurerm_windows_virtual_machine` (× N)               | Sample Windows Server VMs                            |

## Contributing

Issues and pull requests are welcome. Please run `terraform fmt` and `terraform validate` before submitting a PR.

## License

This project is licensed under the [MIT License](LICENSE).


## Contact
For any questions or support, please contact:

- **Omer Abdulrehman**
- **Email:** [consultomer@gmail.com](mailto:consultomer@gmail.com)
- **LinkedIn:** [Omer Abdulrehman](https://www.linkedin.com/in/omerarehman/)
