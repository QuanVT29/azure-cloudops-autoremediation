apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-banking-secrets
  namespace: default
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "${csi_client_id}"
    keyvaultName: "${keyvault_name}"
    cloudName: "AzurePublicCloud"
    objects: |
      array:
        - |
          objectName: sql-connection-string
          objectType: secret
        - |
          objectName: redis-connection-string
          objectType: secret
    tenantId: "${tenant_id}"
  secretObjects:
    - secretName: banking-db-secrets
      type: Opaque
      data:
        - objectName: sql-connection-string
          key: SQL_CONNECTION_STRING
        - objectName: redis-connection-string
          key: REDIS_CONNECTION_STRING