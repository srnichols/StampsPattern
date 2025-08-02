// --------------------------------------------------------------------------------------
// Azure Policy as Code Module for Stamps Pattern
// - Implements automated compliance enforcement
// - Ensures consistent resource configurations
// - Provides governance at scale across all CELLs
// --------------------------------------------------------------------------------------

targetScope = 'managementGroup'

@description('Stamps Pattern organization prefix for policy naming')
param organizationPrefix string = 'stamps'

@description('Environment for policy deployment')
@allowed(['dev', 'test', 'staging', 'prod'])
param environment string = 'prod'

@description('Policy assignment enforcement mode')
@allowed(['Default', 'DoNotEnforce'])
param enforcementMode string = 'Default'

// ============ CUSTOM POLICY DEFINITIONS ============

// Policy: Enforce CAF Naming Conventions for Storage Accounts
resource storageNamingPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${organizationPrefix}-storage-naming-convention'
  properties: {
    displayName: 'Stamps Pattern: Enforce Storage Account Naming Convention'
    description: 'Ensures storage accounts follow CAF naming conventions (st[geo][region][cell])'
    policyType: 'Custom'
    mode: 'All'
    metadata: {
      category: 'Stamps Pattern Governance'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        defaultValue: 'Deny'
        allowedValues: ['Audit', 'Deny', 'Disabled']
        metadata: {
          displayName: 'Effect'
          description: 'The effect of the policy'
        }
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Storage/storageAccounts'
          }
          {
            not: {
              field: 'name'
              like: 'st[a-z][a-z][a-z]*'
            }
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
      }
    }
  }
}

// Policy: Require Managed Identity for All Resources
resource managedIdentityPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${organizationPrefix}-require-managed-identity'
  properties: {
    displayName: 'Stamps Pattern: Require Managed Identity'
    description: 'Ensures all supported resources have managed identity enabled'
    policyType: 'Custom'
    mode: 'All'
    metadata: {
      category: 'Stamps Pattern Security'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        defaultValue: 'Audit'
        allowedValues: ['Audit', 'Deny', 'Disabled']
      }
    }
    policyRule: {
      if: {
        anyOf: [
          {
            allOf: [
              {
                field: 'type'
                equals: 'Microsoft.Storage/storageAccounts'
              }
              {
                field: 'identity.type'
                notEquals: 'SystemAssigned'
              }
            ]
          }
          {
            allOf: [
              {
                field: 'type'
                equals: 'Microsoft.Sql/servers'
              }
              {
                field: 'identity.type'
                notEquals: 'SystemAssigned'
              }
            ]
          }
          {
            allOf: [
              {
                field: 'type'
                equals: 'Microsoft.ContainerRegistry/registries'
              }
              {
                field: 'identity.type'
                notEquals: 'SystemAssigned'
              }
            ]
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
      }
    }
  }
}

// Policy: Enforce TLS 1.2 Minimum
resource tlsPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${organizationPrefix}-enforce-tls12'
  properties: {
    displayName: 'Stamps Pattern: Enforce TLS 1.2 Minimum'
    description: 'Ensures all resources use TLS 1.2 or higher'
    policyType: 'Custom'
    mode: 'All'
    metadata: {
      category: 'Stamps Pattern Security'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        defaultValue: 'Audit'
        allowedValues: ['Audit', 'Deny', 'Disabled']
      }
    }
    policyRule: {
      if: {
        anyOf: [
          {
            allOf: [
              {
                field: 'type'
                equals: 'Microsoft.Storage/storageAccounts'
              }
              {
                field: 'Microsoft.Storage/storageAccounts/minimumTlsVersion'
                notEquals: 'TLS1_2'
              }
            ]
          }
          {
            allOf: [
              {
                field: 'type'
                equals: 'Microsoft.Sql/servers'
              }
              {
                field: 'Microsoft.Sql/servers/minimalTlsVersion'
                notEquals: '1.2'
              }
            ]
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
      }
    }
  }
}

// Policy: Require Diagnostic Settings
resource diagnosticsPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${organizationPrefix}-require-diagnostics'
  properties: {
    displayName: 'Stamps Pattern: Require Diagnostic Settings'
    description: 'Ensures all resources have diagnostic settings configured'
    policyType: 'Custom'
    mode: 'All'
    metadata: {
      category: 'Stamps Pattern Monitoring'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        defaultValue: 'AuditIfNotExists'
        allowedValues: ['AuditIfNotExists', 'DeployIfNotExists', 'Disabled']
      }
      logAnalyticsWorkspaceId: {
        type: 'String'
        metadata: {
          displayName: 'Log Analytics Workspace ID'
          description: 'The Log Analytics workspace ID for diagnostic settings'
        }
      }
    }
    policyRule: {
      if: {
        field: 'type'
        in: [
          'Microsoft.Storage/storageAccounts'
          'Microsoft.Sql/servers'
          'Microsoft.KeyVault/vaults'
          'Microsoft.ContainerRegistry/registries'
          'Microsoft.DocumentDB/databaseAccounts'
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.Insights/diagnosticSettings'
          existenceCondition: {
            field: 'Microsoft.Insights/diagnosticSettings/workspaceId'
            equals: '[parameters(\'logAnalyticsWorkspaceId\')]'
          }
        }
      }
    }
  }
}

// ============ POLICY INITIATIVE (POLICY SET) ============

resource stampsPatternInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: '${organizationPrefix}-stamps-pattern-governance'
  properties: {
    displayName: 'Stamps Pattern: Comprehensive Governance Initiative'
    description: 'Complete set of policies for Stamps Pattern compliance and governance'
    policyType: 'Custom'
    metadata: {
      category: 'Stamps Pattern'
      version: '1.0.0'
    }
    parameters: {
      storageNamingEffect: {
        type: 'String'
        defaultValue: 'Audit'
        allowedValues: ['Audit', 'Deny', 'Disabled']
      }
      managedIdentityEffect: {
        type: 'String'
        defaultValue: 'Audit'
        allowedValues: ['Audit', 'Deny', 'Disabled']
      }
      tlsEffect: {
        type: 'String'
        defaultValue: 'Audit'
        allowedValues: ['Audit', 'Deny', 'Disabled']
      }
      diagnosticsEffect: {
        type: 'String'
        defaultValue: 'AuditIfNotExists'
        allowedValues: ['AuditIfNotExists', 'DeployIfNotExists', 'Disabled']
      }
      logAnalyticsWorkspaceId: {
        type: 'String'
        metadata: {
          displayName: 'Log Analytics Workspace ID'
        }
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: storageNamingPolicy.id
        parameters: {
          effect: {
            value: '[parameters(\'storageNamingEffect\')]'
          }
        }
        policyDefinitionReferenceId: 'StorageNaming'
      }
      {
        policyDefinitionId: managedIdentityPolicy.id
        parameters: {
          effect: {
            value: '[parameters(\'managedIdentityEffect\')]'
          }
        }
        policyDefinitionReferenceId: 'ManagedIdentity'
      }
      {
        policyDefinitionId: tlsPolicy.id
        parameters: {
          effect: {
            value: '[parameters(\'tlsEffect\')]'
          }
        }
        policyDefinitionReferenceId: 'TLSEnforcement'
      }
      {
        policyDefinitionId: diagnosticsPolicy.id
        parameters: {
          effect: {
            value: '[parameters(\'diagnosticsEffect\')]'
          }
          logAnalyticsWorkspaceId: {
            value: '[parameters(\'logAnalyticsWorkspaceId\')]'
          }
        }
        policyDefinitionReferenceId: 'DiagnosticSettings'
      }
    ]
  }
}

// ============ POLICY ASSIGNMENT ============

resource stampsPatternAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: '${organizationPrefix}-stamps-governance-${environment}'
  properties: {
    displayName: 'Stamps Pattern Governance - ${environment}'
    description: 'Enforces Stamps Pattern governance policies across all resources'
    policyDefinitionId: stampsPatternInitiative.id
    enforcementMode: enforcementMode
    parameters: {
      storageNamingEffect: {
        value: environment == 'prod' ? 'Deny' : 'Audit'
      }
      managedIdentityEffect: {
        value: 'Audit'
      }
      tlsEffect: {
        value: environment == 'prod' ? 'Deny' : 'Audit'
      }
      diagnosticsEffect: {
        value: 'AuditIfNotExists'
      }
      logAnalyticsWorkspaceId: {
        value: '/subscriptions/placeholder/resourceGroups/monitoring/providers/Microsoft.OperationalInsights/workspaces/stamps-law'
      }
    }
  }
}

// ============ OUTPUTS ============

output policyInitiativeId string = stampsPatternInitiative.id
output policyAssignmentId string = stampsPatternAssignment.id
output customPolicyIds object = {
  storageNaming: storageNamingPolicy.id
  managedIdentity: managedIdentityPolicy.id
  tlsEnforcement: tlsPolicy.id
  diagnosticSettings: diagnosticsPolicy.id
}
