# filepath: src/infra/outputs.tf
output "gh_action_uai_client_id" {
  description = "User Assigned Identity ID for GitHub Actions"
  value       = azurerm_user_assigned_identity.github_actions.client_id
}
