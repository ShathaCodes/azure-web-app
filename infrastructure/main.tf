resource "azurerm_resource_group" "example" {
  name     = "${var.name_prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.1.0.0/16"]
}

#-------------------------------------------------------------------- KeyVault
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv_account" {
  name                        = "${var.name_prefix}-kv"
  location                    = azurerm_resource_group.example.location
  resource_group_name         = azurerm_resource_group.example.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Purge",
      "Delete"
    ]
  }

  tags = {
    terraform = "true"
  }
}

resource "azurerm_key_vault_secret" "kv" {
  name         = "usernamedb"
  value        = var.login
  key_vault_id = azurerm_key_vault.kv_account.id
}
resource "azurerm_key_vault_secret" "kv2" {
  name         = "passworddb"
  value        = var.password
  key_vault_id = azurerm_key_vault.kv_account.id
}

#-------------------------------------------------------------------- PostgreSQL

resource "azurerm_postgresql_server" "example" {
  name                = "${var.name_prefix}-server"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  administrator_login          = azurerm_key_vault_secret.kv.value
  administrator_login_password = azurerm_key_vault_secret.kv2.value

  sku_name   = "GP_Gen5_4"
  version    = "11"
  storage_mb = 640000

  public_network_access_enabled = true

  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"
}

resource "azurerm_postgresql_database" "example" {
  name                = "${var.name_prefix}-db"
  resource_group_name = azurerm_resource_group.example.name
  server_name         = azurerm_postgresql_server.example.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

#-------------------------------------------------------------------- VM
resource "azurerm_public_ip" "example" {
  name                = "${var.name_prefix}-pub-ip-address"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Production"
  }
}

resource "azurerm_subnet" "example" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

#resource "azurerm_bastion_host" "example" {
#  name                = "examplebastion"
#  location            = azurerm_resource_group.example.location
#  resource_group_name = azurerm_resource_group.example.name
#
#  ip_configuration {
#    name                 = "configuration"
#    subnet_id            = azurerm_subnet.example.id
#    public_ip_address_id = azurerm_public_ip.example.id
#  }
#}

resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "${var.name_prefix}-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "example" {
  name                = "${var.name_prefix}-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example.id
  }
}
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.example.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "trnvbjrnvrk"
  location                 = azurerm_resource_group.example.location
  resource_group_name      = azurerm_resource_group.example.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_linux_virtual_machine" "example" {
  name                = "${var.name_prefix}-back-vm"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]


  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }

  connection {
    type        = "ssh"
    user        = "adminuser"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip_address
  }
  provisioner "file" {
    source      = file("./init.sh")
    destination = "~/script.bash"
  }

  provisioner "remote-exec" {
    inline = [
      "bash -c ~/script.sh"
    ]
  }
}

#-------------------------------------------------------------------- NETWORK

resource "azurerm_private_dns_zone" "dnsprivatezone" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dnszonelink" {
  name                  = "${var.name_prefix}-dnszonelink"
  resource_group_name   = azurerm_resource_group.example.name
  private_dns_zone_name = azurerm_private_dns_zone.dnsprivatezone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_endpoint" "privateendpoint" {
  name                = "${var.name_prefix}-db-private-endpoint"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  subnet_id           = azurerm_subnet.example.id

  private_dns_zone_group {
    name                 = "${var.name_prefix}-privatednszonegroup"
    private_dns_zone_ids = [azurerm_private_dns_zone.dnsprivatezone.id]
  }

  private_service_connection {
    name                           = "${var.name_prefix}-privateserviceconnection"
    private_connection_resource_id = azurerm_postgresql_server.example.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }
}

#-------------------------------------------------------------------- AKS
resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks_subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.0.0/24"]
}



resource "azurerm_kubernetes_cluster" "app" {
  name                = "${var.name_prefix}-aks"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "appaks"
  sku_tier            = "Free"

  default_node_pool {
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Development"
  }
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.app.kube_config.0.host
  username               = azurerm_kubernetes_cluster.app.kube_config.0.username
  password               = azurerm_kubernetes_cluster.app.kube_config.0.password
  client_certificate     = base64decode(azurerm_kubernetes_cluster.app.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.app.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.app.kube_config.0.cluster_ca_certificate)
}

module "basic_setup" {
  source = "./modules/setup-front-k8s"

  providers = {
    kubernetes = kubernetes
  }

  back_ip     = azurerm_linux_virtual_machine.example.private_ip_address
  name_prefix = var.name_prefix
}
