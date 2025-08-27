// globalIdentityRoleAssignment.sub.bicep
// Subscription-scoped: Assigns Contributor to a user-assigned managed identity
// Usage: az deployment sub create --location <location> --template-file globalIdentityRoleAssignment.sub.bicep --parameters identityResourceId=<id> principalId=<principalId>

targetScope = 'subscription'

param identityResourceId string
param principalId string

resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(identityResourceId, 'contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
