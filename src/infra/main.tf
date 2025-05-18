// Resource Group to contain all resources
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

// Retrieve current client configuration (tenant and subscription info)
data "azurerm_client_config" "current" {}

// User-assigned identity for the Container App
resource "azurerm_user_assigned_identity" "app_identity" {
  name                = "${var.prefix}-uai"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

// Log Analytics Workspace for Container App logs
resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.prefix}-law"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  daily_quota_gb      = 1
  retention_in_days   = 30
}

// Virtual Network for network isolation
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

// Subnet for Container App Environment with private endpoint policies disabled
resource "azurerm_subnet" "app_env_subnet" {
  name                                          = "app-env"
  resource_group_name                           = azurerm_resource_group.rg.name
  virtual_network_name                          = azurerm_virtual_network.vnet.name
  address_prefixes                              = [var.subnet_app]
  private_link_service_network_policies_enabled = true
}

// Subnet for SQL Private Endpoint to connect securely to SQL Server
resource "azurerm_subnet" "pe_subnet" {
  name                                          = "sql-pe"
  resource_group_name                           = azurerm_resource_group.rg.name
  virtual_network_name                          = azurerm_virtual_network.vnet.name
  address_prefixes                              = [var.subnet_pe]
  private_link_service_network_policies_enabled = true
}

// Container App Environment integrated with VNet and Log Analytics
resource "azurerm_container_app_environment" "env" {
  name                       = "${var.prefix}-env"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  logs_destination           = "log-analytics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  infrastructure_subnet_id   = azurerm_subnet.app_env_subnet.id
}

// Container App running the Go API
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
      env {
        name  = "AZURE_TENANT_ID"
        value = data.azurerm_client_config.current.tenant_id
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.app_identity.client_id
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

// Azure SQL Server with Managed Identity as AD admin
resource "azurerm_mssql_server" "sql" {
  name                          = "${var.prefix}-sql"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  # configure Azure AD admin using the user-assigned identity
  azuread_administrator {
    azuread_authentication_only = true
    login_username              = azurerm_user_assigned_identity.app_identity.name
    object_id                   = azurerm_user_assigned_identity.app_identity.principal_id
    tenant_id                   = data.azurerm_client_config.current.tenant_id
  }
}

// Azure SQL Database for application data
resource "azurerm_mssql_database" "db" {
  name      = "${var.prefix}-db"
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "S0"
}

// Private Endpoint for SQL Server to allow private connectivity
resource "azurerm_private_endpoint" "sql_pe" {
  name                = "${var.prefix}-sql-pe"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = azurerm_subnet.pe_subnet.id

  private_service_connection {
    name                           = "sql-psc"
    private_connection_resource_id = azurerm_mssql_server.sql.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
}

// Private DNS Zone for SQL Private Endpoint resolution
resource "azurerm_private_dns_zone" "sql_zone" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

// Link the Private DNS Zone to the VNet
resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "link-to-vnet"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

// A record for SQL Private Endpoint to resolve server privately
resource "azurerm_private_dns_a_record" "sql_pe_record" {
  name                = azurerm_mssql_server.sql.name
  zone_name           = azurerm_private_dns_zone.sql_zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.sql_pe.private_service_connection[0].private_ip_address]
}

// User-assigned identity for GitHub Actions with federated credentials
resource "azurerm_user_assigned_identity" "github_actions" {
  name                = "${var.prefix}-uai-gh"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

// Federated Identity Credential for GitHub Actions
resource "azurerm_federated_identity_credential" "github_actions" {
  name                = "${var.prefix}-fedcrd-gh"
  resource_group_name = azurerm_resource_group.rg.name
  parent_id           = azurerm_user_assigned_identity.github_actions.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = var.oidc_subject
}

// Role Assignment for GitHub Actions identity in Resource Group
resource "azurerm_role_assignment" "github_actions" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
}
