terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.0.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "ntnu-cloud-tfstate"
    storage_account_name = "ntnucloudtfstate"
    container_name       = "ntnu-cloud-tfstate-container"
    key                  = "tfstate"
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "ntnu-rg" {
  name     = "ntnu-cloud-resources"
  location = "West Europe"
  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "ntnu-vn" {
  name                = "ntnu-network"
  resource_group_name = azurerm_resource_group.ntnu-rg.name
  location            = azurerm_resource_group.ntnu-rg.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet" "ntnu-subnet" {
  name                 = "ntnu-subnet"
  resource_group_name  = azurerm_resource_group.ntnu-rg.name
  virtual_network_name = azurerm_virtual_network.ntnu-vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "ntnu-sg" {
  name                = "ntnu-sg"
  location            = azurerm_resource_group.ntnu-rg.location
  resource_group_name = azurerm_resource_group.ntnu-rg.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "ntnu-dev-rule" {
  name                   = "ntnu-dev-rule"
  priority               = 100
  direction              = "Inbound"
  access                 = "Allow"
  protocol               = "*"
  source_port_range      = "*"
  destination_port_range = "*"
  # Best to specify your ip
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ntnu-rg.name
  network_security_group_name = azurerm_network_security_group.ntnu-sg.name
}

resource "azurerm_subnet_network_security_group_association" "ntnu-sga" {
  subnet_id                 = azurerm_subnet.ntnu-subnet.id
  network_security_group_id = azurerm_network_security_group.ntnu-sg.id
}

resource "azurerm_public_ip" "ntnu-ip" {
  name                = "ntnu-ip"
  resource_group_name = azurerm_resource_group.ntnu-rg.name
  location            = azurerm_resource_group.ntnu-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "ntnu-nic" {
  name                = "ntnu-nic"
  location            = azurerm_resource_group.ntnu-rg.location
  resource_group_name = azurerm_resource_group.ntnu-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.ntnu-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ntnu-ip.id
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_linux_virtual_machine" "ntnu-vm" {
  name                  = "ntnu-vm"
  resource_group_name   = azurerm_resource_group.ntnu-rg.name
  location              = azurerm_resource_group.ntnu-rg.location
  size                  = "Standard_F2"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.ntnu-nic.id]

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/ntnuazurekey.pub")
  }

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
    environment = "dev"
  }
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.ntnu-vm.name}: ${azurerm_linux_virtual_machine.ntnu-vm.public_ip_address}"
}