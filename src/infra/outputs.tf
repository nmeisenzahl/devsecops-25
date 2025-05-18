# filepath: src/infra/outputs.tf
output "gh_action_uai_client_id" {
  description = "User Assigned Identity ID for GitHub Actions"
  value       = azurerm_user_assigned_identity.github_actions.client_id
}

output "sql_server_name" {
  description = "SQL Server Name"
  value       = azurerm_mssql_server.sql.name

}

output "sql_database_name" {
  description = "SQL Database Name"
  value       = azurerm_mssql_database.db.name

}

output "ip_fqdn" {
  description = "IP FQDN for the Application Gateway"
  value       = azurerm_public_ip.appgw_pip.fqdn
}
