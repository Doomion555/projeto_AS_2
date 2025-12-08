terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
    }
  }
  required_version = ">=1.2.0"
}

provider "azurerm" {
  features {}
  subscription_id = "6d49d3f9-ff99-4677-9ac5-3f3f21c05299"
}

# 1. Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "dhcp-test-rg"
  location = "switzerlandnorth"
}

# 2. Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "dhcp-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# 3. Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "dhcp-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# 4. Public IP
resource "azurerm_public_ip" "publicip" {
  name                = "dhcp-vm-publicip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 5. Network Interface
resource "azurerm_network_interface" "nic" {
  name                = "dhcp-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address		  = "10.0.2.10"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

# 6. Network Security Group (SSH)
resource "azurerm_network_security_group" "nsg" {
  name                = "dhcp-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "ssh_rule" {
  name                        = "SSH_Access"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_interface_security_group_association" "nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 7. Linux VM (DHCP Server)
resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "dhcp-vm"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = "Standard_B2S"
  network_interface_ids           = [azurerm_network_interface.nic.id]
  disable_password_authentication = false
  admin_username                  = "azureuser"
  admin_password                  = "Baguette123!"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    Environment = "DHCP-Test"
  }
}

# 8. Output do Public IP
output "public_ip_address" {
  value = azurerm_public_ip.publicip.ip_address
}
