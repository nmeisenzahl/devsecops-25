resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "app_identity" {
  name                = "${var.prefix}-uai"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.prefix}-law"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  daily_quota_gb      = 1
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "env" {
  name                       = "${var.prefix}-env"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  logs_destination           = "log-analytics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
}

resource "azurerm_container_app" "app" {
  name                         = "${var.prefix}-app"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app_identity.id]
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "app"
      image  = var.container_image
      cpu    = "0.25"
      memory = "0.5Gi"
      // pass database connection details via environment variables
      env {
        name  = "DB_SERVER"
        value = azurerm_mssql_server.sql.fully_qualified_domain_name
      }
      env {
        name  = "DB_DATABASE"
        value = azurerm_mssql_database.db.name
      }
    }
    min_replicas = 1
    max_replicas = 3
  }

  lifecycle {
    ignore_changes = [
      template[0].container[0].image
    ]
  }
}

resource "azurerm_mssql_server" "sql" {
  name                = "${var.prefix}-sql"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  version             = "12.0"
  minimum_tls_version = "1.2"

  # configure Azure AD admin using the user-assigned identity
  azuread_administrator {
    azuread_authentication_only = true
    login_username              = azurerm_user_assigned_identity.app_identity.name
    object_id                   = azurerm_user_assigned_identity.app_identity.principal_id
    tenant_id                   = data.azurerm_client_config.current.tenant_id
  }
}

resource "azurerm_mssql_database" "db" {
  name      = "${var.prefix}-db"
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "S0"
}
