@description('The name of the Key Vault')
param name string

@description('The Azure region for the Key Vault')
param location string

@description('Tags for the Key Vault')
param tags object = {}

@description('The tenant ID for the Key Vault')
param tenantId string = subscription().tenantId


@description('The SKU for the Key Vault')
param skuName string = 'standard'

@description('Access policies to assign to the Key Vault')
param accessPolicies array = []

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: skuName
    }
    tenantId: tenantId
    accessPolicies: accessPolicies
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
  }
}

output name string = keyVault.name
output vaultName string = keyVault.name
output id string = keyVault.id
