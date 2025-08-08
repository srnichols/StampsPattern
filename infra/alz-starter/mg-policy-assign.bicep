// Minimal management group policy assignment (ALZ starter)
// NOTE: For DeployIfNotExists/Modify policies, add a managed identity and location.

targetScope = 'managementGroup'

@description('Name of the policy assignment (unique within scope)')
param policyAssignmentName string

@description('Display name for the policy assignment')
param displayName string

@description('Policy or Initiative (set) definition resource ID. Example: /providers/Microsoft.Authorization/policySetDefinitions/<GUID>')
param policyDefinitionId string

@description('Optional parameters object passed to the policy/initiative')
param parameters object = {}

@description('Enforcement mode: Default or DoNotEnforce')
@allowed([
  'Default'
  'DoNotEnforce'
])
param enforcementMode string = 'Default'

@description('Optional description for the assignment')
param assignmentDescription string = ''

resource assignment 'Microsoft.Authorization/policyAssignments@2022-09-01' = {
  name: policyAssignmentName
  properties: {
    displayName: displayName
    description: assignmentDescription
    policyDefinitionId: policyDefinitionId
    enforcementMode: enforcementMode
    parameters: parameters
  }
  // To support DeployIfNotExists/Modify add:
  // identity: {
  //   type: 'SystemAssigned'
  // }
  // location: 'eastus'
}

output assignmentResourceId string = assignment.id
