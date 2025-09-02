// globalIdentityRoleAssignment.sub.bicep
// Subscription-scoped: Assigns Contributor to a user-assigned managed identity
// Usage: az deployment sub create --location <location> --template-file globalIdentityRoleAssignment.sub.bicep --parameters principalId=<principalId>

targetScope = 'subscription'

param principalId string

// Use a deterministic role assignment name based on scope, principal, and role
var contributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // Name incorporates subscription scope, principal, and role to avoid forbidden updates if principal changes
  name: guid(subscription().id, principalId, contributorRoleDefinitionId)
  properties: {
    roleDefinitionId: contributorRoleDefinitionId // Contributor
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
