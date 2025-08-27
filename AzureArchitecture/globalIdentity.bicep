// globalIdentity.bicep
// Creates a user-assigned managed identity in the global resource group and assigns Contributor at the subscription scope

param location string = resourceGroup().location
param identityName string = 'global-deployment-identity'
param subscriptionId string = subscription().subscriptionId

resource globalIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}


resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(globalIdentity.properties.principalId)) {
  name: guid(globalIdentity.id, 'contributor')
  scope: subscription()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: globalIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output identityResourceId string = globalIdentity.id
output principalId string = globalIdentity.properties.principalId
