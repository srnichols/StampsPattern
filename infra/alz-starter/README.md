# ALZ Starter (Management Group Policy Assignments and Subscription Map)

This folder contains minimal, safe-to-clone Bicep starters to help align your Stamps Pattern with Azure Landing Zones (ALZ).

Contents:
- mg-policy-assign.bicep — Assign a Policy/Initiative at a management group scope.
- subscription-map.bicep — Reference existing platform/shared-services and cell subscriptions at tenant scope (no creation).

Notes:
- mg-policy-assign deploys at managementGroup scope. For DeployIfNotExists/Modify policies, add identity and location to the assignment resource.
- subscription-map only maps existing subscriptions. No creation path is included.

## Usage examples

### Assign an initiative to the platform MG

```bicep
targetScope = 'managementGroup'

param policyAssignmentName string = 'alz-platform-initiative'
param displayName string = 'ALZ Platform Baseline'
param policyDefinitionId string = '/providers/Microsoft.Authorization/policySetDefinitions/abcdef01-2345-6789-abcd-ef0123456789'
param parameters object = {}
param enforcementMode string = 'Default'

module assign './mg-policy-assign.bicep' = {
  name: 'assign-platform-initiative'
  params: {
    policyAssignmentName: policyAssignmentName
    displayName: displayName
    policyDefinitionId: policyDefinitionId
    parameters: parameters
    enforcementMode: enforcementMode
  }
}

// Deploy with parameters file (management group scope)
// az deployment mg create \
//   --management-group-id <platform-mg-id> \
//   --template-file ./infra/alz-starter/mg-policy-assign.bicep \
//   --parameters @./infra/alz-starter/mg-policy-assign.parameters.json
```

### Map existing subscriptions (no creation)

```bicep
targetScope = 'tenant'

param platform object = {
  management: { subscriptionId: '/subscriptions/00000000-0000-0000-0000-000000000000' }
  connectivity: { subscriptionId: '/subscriptions/11111111-1111-1111-1111-111111111111' }
  sharedServices: { subscriptionId: '/subscriptions/22222222-2222-2222-2222-222222222222' }
}

param cells array = [
  { name: 'cell-001', displayName: 'Cell-001', subscriptionId: '/subscriptions/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' },
  { name: 'cell-002', displayName: 'Cell-002', subscriptionId: '/subscriptions/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' }
]

module map './subscription-map.bicep' = {
  name: 'map-existing'
  params: {
    platform: platform
    cells: cells
  }
}

// Deploy with parameters file (tenant scope)
// az deployment tenant create \
//   --template-file ./infra/alz-starter/subscription-map.bicep \
//   --parameters @./infra/alz-starter/subscription-map.parameters.json
```

## Next steps
- Replace placeholder IDs with your actual policy/initiative IDs.
- For subscription creation, if ever needed later, implement Microsoft.Subscription/aliases or Microsoft.Billing calls and ensure proper RBAC and billing permissions.
- Consider adding modules for MG hierarchy creation and policy assignment at each MG per ALZ guidance.
