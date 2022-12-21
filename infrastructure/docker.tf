resource "azurerm_container_registry" "example" {
  name                = "shathacodes"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Basic"
}

resource "azurerm_role_assignment" "example" {
  principal_id                     = azurerm_kubernetes_cluster.app.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.example.id
  skip_service_principal_aad_check = true
}

resource "azurerm_container_registry_task" "example" {
  name                  = "${var.name_prefix}-task"
  container_registry_id = azurerm_container_registry.example.id
  platform {
    os = "Linux"
  }
  docker_step {
    dockerfile_path      = "Front/Dockerfile"
    context_path         = "https://github.com/ShathaCodes/azure-web-app#main"
    context_access_token = "<token>"
    image_names          = ["bookshopfront:cloud"]
  }
}
resource "azurerm_container_registry_task_schedule_run_now" "example" {
  container_registry_task_id = azurerm_container_registry_task.example.id
}