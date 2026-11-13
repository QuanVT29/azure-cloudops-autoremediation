# Automatically generate Kubernetes manifests from Terraform outputs

resource "local_file" "secret_provider_class" {
  filename = "${path.module}/../../../../app/manifests/01-secret-provider-class.yaml"

  content = templatefile("${path.module}/../../../../app/manifests/01-secret-provider-class.yaml.tpl", {
    csi_client_id = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].client_id
    keyvault_name = data.azurerm_key_vault.vault.name
    tenant_id     = data.azurerm_client_config.current.tenant_id
  })
}