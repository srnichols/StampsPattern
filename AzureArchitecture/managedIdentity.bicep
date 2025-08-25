@description('The name of the user-assigned managed identity')
param name string
@description('The Azure region for the managed identity')
param location string
@description('Tags for the managed identity')
param tags object = {}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

output id string = identity.id
output principalId string = identity.properties.principalId
