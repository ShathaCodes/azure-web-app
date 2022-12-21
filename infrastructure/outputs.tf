output "resource_group_name" {
  value = azurerm_resource_group.example.name
}

output "azurerm_postgresql_server" {
  value = azurerm_postgresql_server.example.name
}

output "postgresql_server_database_name" {
  value = azurerm_postgresql_database.example.name
}


output "public_ip" {
  value = azurerm_public_ip.example.ip_address
}

output "private_ip" {
  value = azurerm_linux_virtual_machine.example.private_ip_address
}

output "private_dns_zone_name" {
  value = azurerm_private_dns_zone.dnsprivatezone.name
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.app.kube_config_raw
  sensitive = true
}

resource "local_file" "kubeconfig" {
  depends_on = [azurerm_kubernetes_cluster.app]
  filename   = "kubeconfig"
  content    = azurerm_kubernetes_cluster.app.kube_config_raw
}
output "keyvault_uri" {
  value       = azurerm_key_vault.kv_account.vault_uri
  description = "The key vault uri."
}
output "keyvault_secret" {
  value       = azurerm_key_vault_secret.kv.value
  description = "The key vault secret username."
  sensitive   = true
}
