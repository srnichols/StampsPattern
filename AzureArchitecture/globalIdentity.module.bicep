// globalIdentity.module.bicep
// Resource group-scoped: Creates a user-assigned managed identity
param location string
param identityName string = 'global-deployment-identity'

resource globalIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

output identityResourceId string = globalIdentity.id
output principalId string = globalIdentity.properties.principalId
