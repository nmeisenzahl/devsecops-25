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
