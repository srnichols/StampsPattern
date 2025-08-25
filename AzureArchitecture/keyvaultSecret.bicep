@description('The name of the Key Vault')
param keyVaultName string
@description('The name of the secret')
param secretName string
@description('The value of the secret')
@secure()
param secretValue string

resource secret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: '${keyVaultName}/${secretName}'
  properties: {
    value: secretValue
  }
}

output id string = secret.id
