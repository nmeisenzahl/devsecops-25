// filepath: src/infra/variables.tf

variable "prefix" {
  description = "Prefix for all resources"
  type        = string
  default     = "devsecops"
}

variable "location" {
  description = "Azure region for the resource group"
  type        = string
  default     = "Sweden Central"
}

variable "container_image" {
  description = "Container registry image reference"
  type        = string
  default     = "ghcr.io/nmeisenzahl/devsecops-25:latest"
}

variable "oidc_subject" {
  description = "OIDC subject for the GitHub Actions workflow"
  type        = string
  default     = "repo:nmeisenzahl/devsecops-25:ref:refs/heads/main"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_app" {
  description = "Subnet for Container App Environment"
  type        = string
  default     = "10.0.0.0/23"
}

variable "subnet_pe" {
  description = "Subnet for Private Endpoint"
  type        = string
  default     = "10.0.2.0/24"
}

variable "appgw_subnet_prefix" {
  description = "Subnet prefix for Application Gateway"
  type        = string
  default     = "10.0.3.0/24"
}
