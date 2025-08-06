// Azure Defender and Advanced Security Configuration
// This file extends the existing security implementation with Azure Defender
// Note: Azure Defender requires subscription scope

targetScope = 'subscription'

@description('Enable Azure Defender for all supported resource types')
param enableAzureDefender bool = true

@description('Enable advanced threat protection features')
param enableAdvancedThreatProtection bool = true

@description('Security contact email for alerts')
param securityContactEmail string = 'security@contoso.com'

@description('Resource group name for resource-scoped resources')
param resourceGroupName string = 'rg-stamps-dev'

@description('Location for regional resources')
param location string = 'eastus'

@description('Environment identifier')
param environment string = 'dev'

@description('Unique resource token')
param resourceToken string = uniqueString(subscription().subscriptionId, resourceGroupName)

// ============ AZURE DEFENDER CONFIGURATION ============

// Security Center Subscription Pricing (Azure Defender)
resource defenderForAppService 'Microsoft.Security/pricings@2022-03-01' = if (enableAzureDefender) {
  name: 'AppServices'
  properties: {
    pricingTier: 'Standard'
  }
}

resource defenderForSql 'Microsoft.Security/pricings@2022-03-01' = if (enableAzureDefender) {
  name: 'SqlServers'
  properties: {
    pricingTier: 'Standard'
  }
}

resource defenderForStorage 'Microsoft.Security/pricings@2022-03-01' = if (enableAzureDefender) {
  name: 'StorageAccounts'
  properties: {
    pricingTier: 'Standard'
  }
}

resource defenderForContainers 'Microsoft.Security/pricings@2022-03-01' = if (enableAzureDefender) {
  name: 'Containers'
  properties: {
    pricingTier: 'Standard'
  }
}

resource defenderForKeyVault 'Microsoft.Security/pricings@2022-03-01' = if (enableAzureDefender) {
  name: 'KeyVaults'
  properties: {
    pricingTier: 'Standard'
  }
}

resource defenderForArm 'Microsoft.Security/pricings@2022-03-01' = if (enableAzureDefender) {
  name: 'Arm'
  properties: {
    pricingTier: 'Standard'
  }
}

// Security Center Contact
resource securityContact 'Microsoft.Security/securityContacts@2020-01-01-preview' = if (enableAzureDefender) {
  name: 'default'
  properties: {
    emails: securityContactEmail
    notificationsByRole: {
      state: 'On'
      roles: ['Owner']
    }
    alertNotifications: {
      state: 'On'
      minimalSeverity: 'Medium'
    }
  }
}

// ============ RESOURCE GROUP SCOPED RESOURCES ============

module resourceGroupScopedSecurity 'advancedSecurityResourceGroup.bicep' = {
  name: 'securityResourceGroupDeployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    environment: environment
    resourceToken: resourceToken
    securityContactEmail: securityContactEmail
    enableAdvancedThreatProtection: enableAdvancedThreatProtection
  }
}

// ============ OUTPUTS ============

@description('Azure Defender status')
output azureDefenderEnabled bool = enableAzureDefender

@description('Security contact email')
output securityContactEmail string = securityContactEmail

@description('Resource Group Security Module Output')
output resourceGroupSecurityOutputs object = resourceGroupScopedSecurity.outputs

// ============ ADVANCED THREAT PROTECTION ============

// Advanced Threat Protection for SQL
resource sqlAdvancedThreatProtection 'Microsoft.Sql/servers/securityAlertPolicies@2022-11-01-preview' = if (enableAdvancedThreatProtection) {
  name: 'sqlserver-${resourceToken}/Default'
  properties: {
    state: 'Enabled'
    emailAccountAdmins: true
    emailAddresses: [securityContactEmail]
    retentionDays: 30
    disabledAlerts: []
  }
  dependsOn: [
    // Assumes SQL server exists from main deployment
  ]
}

// Advanced Threat Protection for Storage
resource storageAdvancedThreatProtection 'Microsoft.Storage/storageAccounts/providers/advancedThreatProtectionSettings@2019-01-01' = if (enableAdvancedThreatProtection) {
  name: 'sa${resourceToken}/Microsoft.Security/current'
  properties: {
    isEnabled: true
  }
  dependsOn: [
    // Assumes storage account exists from main deployment
  ]
}

// ============ KEY VAULT ACCESS POLICY MONITORING ============

// Action Group for Security Alerts
resource securityActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-security-${resourceToken}'
  location: 'global'
  properties: {
    groupShortName: 'SecAlert'
    enabled: true
    emailReceivers: [
      {
        name: 'Security Team'
        emailAddress: securityContactEmail
        useCommonAlertSchema: true
      }
    ]
    smsReceivers: []
    webhookReceivers: []
    azureFunctionReceivers: []
    logicAppReceivers: []
  }
}

// Key Vault Access Policy Alert
resource keyVaultAccessAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'KeyVault Unauthorized Access Alert'
  location: 'global'
  properties: {
    description: 'Alert when unauthorized access attempts are made to Key Vault'
    severity: 1
    enabled: true
    scopes: [
      // Will be populated with Key Vault resource ID from main deployment
      '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.KeyVault/vaults/kv-${resourceToken}'
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Unauthorized access attempts'
          metricName: 'ServiceApiResult'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'ActivityName'
              operator: 'Include'
              values: ['VaultGet', 'VaultPut']
            }
            {
              name: 'StatusCode'
              operator: 'Include'
              values: ['403', '401']
            }
          ]
        }
      ]
    }
    actions: [
      {
        actionGroupId: securityActionGroup.id
      }
    ]
  }
}

// ============ SECURITY MONITORING WORKBOOK ============

resource securityMonitoringWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: 'security-monitoring-${resourceToken}'
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Azure Stamps Pattern - Security Monitoring'
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# Azure Stamps Pattern - Security Monitoring Dashboard\\n\\n## Key Security Metrics\\n- Azure Defender alerts\\n- Authentication failures\\n- Key Vault access anomalies\\n- Network security events"
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "SecurityAlert\\n| where TimeGenerated > ago(24h)\\n| summarize Count = count() by AlertSeverity\\n| render piechart",
        "size": 0,
        "title": "Azure Defender Alerts (24h)",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "KeyVaultData\\n| where TimeGenerated > ago(24h)\\n| where ResultSignature == \\"403\\" or ResultSignature == \\"401\\"\\n| summarize Count = count() by CallerIpAddress\\n| top 10 by Count desc",
        "size": 0,
        "title": "Key Vault Unauthorized Access Attempts",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "AzureDiagnostics\\n| where Category == \\"FunctionAppLogs\\"\\n| where Level == \\"Error\\"\\n| where TimeGenerated > ago(24h)\\n| summarize Count = count() by FunctionName\\n| top 10 by Count desc",
        "size": 0,
        "title": "Function App Errors (24h)",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      }
    }
  ]
}
'''
    category: 'workbook'
    sourceId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.OperationalInsights/workspaces/law-${resourceToken}'
  }
}

// ============ PENETRATION TESTING AUTOMATION ============

// Logic App for Automated Security Testing
resource securityTestingLogicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'logic-security-testing-${resourceToken}'
  location: location
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        'Recurrence': {
          recurrence: {
            frequency: 'Week'
            interval: 1
            schedule: {
              hours: ['02'] // Run at 2 AM
              minutes: [0]
              weekDays: ['Sunday']
            }
          }
          type: 'Recurrence'
        }
      }
      actions: {
        'Trigger-Security-Scan': {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: 'https://api.github.com/repos/srnichols/StampsPattern/dispatches'
            headers: {
              'Authorization': 'token ${listSecrets(resourceId('Microsoft.KeyVault/vaults', 'kv-${resourceToken}'), '2023-02-01').value}'
              'Accept': 'application/vnd.github.v3+json'
              'Content-Type': 'application/json'
            }
            body: {
              event_type: 'security-scan'
              client_payload: {
                environment: environment
                scan_type: 'comprehensive'
              }
            }
          }
        }
      }
    }
  }
}

// ============ OUTPUTS ============

@description('Azure Defender status')
output azureDefenderEnabled bool = enableAzureDefender

@description('Security contact email')
output securityContactEmail string = securityContactEmail

@description('Security Action Group ID')
output securityActionGroupId string = securityActionGroup.id

@description('Security Monitoring Workbook ID')
output securityWorkbookId string = securityMonitoringWorkbook.id
