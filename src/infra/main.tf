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

// Subnet for Application Gateway
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.appgw_subnet_prefix]
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

// Managed identity for Application Gateway to access Key Vault
resource "azurerm_user_assigned_identity" "appgw_identity" {
  name                = "${var.prefix}-uai-agw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

// Generate a random suffix for unique naming
resource "random_integer" "kv_suffix" {
  min = 10
  max = 99
}

// Key Vault for TLS certificate storage
resource "azurerm_key_vault" "kv" {
  name                       = "${var.prefix}${random_integer.kv_suffix.result}kv"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  enable_rbac_authorization  = true
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}

// Self-signed certificate issuance policy
resource "azurerm_key_vault_certificate" "cert" {
  name         = "app-cert"
  key_vault_id = azurerm_key_vault.kv.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject            = "CN=${azurerm_public_ip.appgw_pip.fqdn}"
      validity_in_months = 3
    }
  }
  lifecycle {
    ignore_changes = [certificate_policy]
  }
  depends_on = [azurerm_role_assignment.terraform]
}

// Grant Terraform identity access to Key Vault secrets
resource "azurerm_role_assignment" "terraform" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Certificates Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

// Grant AppGW identity access to Key Vault secrets
resource "azurerm_role_assignment" "appgw" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = azurerm_user_assigned_identity.appgw_identity.principal_id
}

// Public IP for Application Gateway
resource "azurerm_public_ip" "appgw_pip" {
  name                = "${var.prefix}-pip-agw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.prefix}-appgw"
}

// Application Gateway v2 with firewall policy
resource "azurerm_web_application_firewall_policy" "waf_policy" {
  name                = "${var.prefix}-wafpolicy"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  policy_settings {
    mode    = "Prevention"
    enabled = true
  }

  managed_rules {
    managed_rule_set {
      type    = "Microsoft_DefaultRuleSet"
      version = "2.1"
    }
    managed_rule_set {
      type    = "Microsoft_BotManagerRuleSet"
      version = "1.1"
    }
  }
}

// Update Application Gateway to use WAF policy and public IP FQDN
resource "azurerm_application_gateway" "appgw" {
  name                = "${var.prefix}-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }
  gateway_ip_configuration {
    name      = "appgwIpConfig"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_port {
    name = "port443"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "publicFrontEnd"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  ssl_certificate {
    name                = "appCert"
    key_vault_secret_id = azurerm_key_vault_certificate.cert.secret_id
  }

  http_listener {
    name                           = "httpsListener"
    frontend_ip_configuration_name = "publicFrontEnd"
    frontend_port_name             = "port443"
    protocol                       = "Https"
    ssl_certificate_name           = "appCert"
  }

  backend_address_pool {
    name  = "appPool"
    fqdns = [azurerm_container_app.app.ingress[0].fqdn]
  }

  probe {
    name                = "appProbe"
    protocol            = "Https"
    host                = azurerm_container_app.app.ingress[0].fqdn
    path                = "/v1/healthz"
    interval            = 60
    timeout             = 30
    unhealthy_threshold = 3
  }

  backend_http_settings {
    name                                = "httpSettings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 30
    pick_host_name_from_backend_address = true
    probe_name                          = "appProbe"
  }

  request_routing_rule {
    name                       = "rule1"
    rule_type                  = "Basic"
    http_listener_name         = "httpsListener"
    backend_address_pool_name  = "appPool"
    backend_http_settings_name = "httpSettings"
    priority                   = "100"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw_identity.id]
  }

  // Attach WAF policy
  firewall_policy_id = azurerm_web_application_firewall_policy.waf_policy.id
}
