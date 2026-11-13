# Output AKS cluster details and management access commands

output "aks_cluster_name" {
  description = "The Name of the provisioned AKS Cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  description = "The Resource ID of the provisioned AKS Cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "oidc_issuer_url" {
  description = "The OIDC Issuer URL for Kubernetes Workload Identity"
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "key_vault_secrets_provider_client_id" {
  description = "Client ID of the Secrets Store CSI Driver User-Assigned Identity"
  value       = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].client_id
}

output "configure_kubectl_command" {
  description = "Azure CLI command to obtain local kubectl credentials"
  value       = "az aks get-credentials --resource-group ${data.azurerm_resource_group.compute.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing"
}