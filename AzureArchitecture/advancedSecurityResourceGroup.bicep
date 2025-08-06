// Resource Group Scoped Security Resources
// This file contains security resources that must be deployed at resource group scope

@description('Location for regional resources')
param location string = resourceGroup().location

@description('Environment identifier')
param environment string = 'dev'

@description('Unique resource token')
param resourceToken string = take(uniqueString(resourceGroup().id), 6)

@description('Security contact email for alerts')
param securityContactEmail string = 'security@contoso.com'

@description('Enable advanced threat protection features')
param enableAdvancedThreatProtection bool = true

// ============ ADVANCED THREAT PROTECTION ============

// Advanced Threat Protection for SQL (assumes SQL server exists)
resource sqlAdvancedThreatProtection 'Microsoft.Sql/servers/securityAlertPolicies@2022-11-01-preview' = if (enableAdvancedThreatProtection) {
  name: 'sqlserver-${resourceToken}/Default'
  properties: {
    state: 'Enabled'
    emailAccountAdmins: true
    emailAddresses: [securityContactEmail]
    retentionDays: 30
    disabledAlerts: []
  }
}

// Advanced Threat Protection for Storage (assumes storage account exists)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: 'stamps${resourceToken}'
}

resource storageAdvancedThreatProtection 'Microsoft.Security/advancedThreatProtectionSettings@2019-01-01' = if (enableAdvancedThreatProtection) {
  scope: storageAccount
  name: 'current'
  properties: {
    isEnabled: true
  }
}

// ============ MONITORING & ALERTING ============

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

// Key Vault Access Policy Alert (assumes Key Vault exists)
resource keyVaultAccessAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'KeyVault Unauthorized Access Alert'
  location: 'global'
  properties: {
    description: 'Alert when unauthorized access attempts are made to Key Vault'
    severity: 1
    enabled: true
    scopes: [
      resourceId('Microsoft.KeyVault/vaults', 'kv-${resourceToken}')
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
          criterionType: 'StaticThresholdCriterion'
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

// Cache Performance Alert for Redis
resource cachePerformanceAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Redis Cache Hit Ratio Alert'
  location: 'global'
  properties: {
    description: 'Alert when Redis cache hit ratio drops below 80%'
    severity: 2
    enabled: true
    scopes: [
      resourceId('Microsoft.Cache/redis', 'redis-${resourceToken}')
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Low cache hit ratio'
          metricName: 'CacheHitRate'
          operator: 'LessThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
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

// Function App Performance Alert
resource functionPerformanceAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Function App High Latency Alert'
  location: 'global'
  properties: {
    description: 'Alert when Function App response time exceeds 200ms'
    severity: 2
    enabled: true
    scopes: [
      resourceId('Microsoft.Web/sites', 'fa-stamps-${resourceToken}')
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'High response time'
          metricName: 'AverageResponseTime'
          operator: 'GreaterThan'
          threshold: 200
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
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

// Assumes Log Analytics workspace exists
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: 'law-${resourceToken}'
}

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
        "json": "# Azure Stamps Pattern - Security Monitoring Dashboard\\n\\n## Key Security Metrics\\n- Azure Defender alerts\\n- Authentication failures\\n- Key Vault access anomalies\\n- Network security events\\n- Cache performance metrics"
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
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "AzureMetrics\\n| where ResourceProvider == \\"MICROSOFT.CACHE\\"\\n| where MetricName == \\"CacheHitRate\\"\\n| where TimeGenerated > ago(24h)\\n| summarize avg(Average) by bin(TimeGenerated, 1h)\\n| render timechart",
        "size": 0,
        "title": "Redis Cache Hit Rate (24h)",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      }
    }
  ]
}
'''
    category: 'workbook'
    sourceId: logAnalyticsWorkspace.id
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
        Recurrence: {
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
              Authorization: 'token @{parameters(\'github-token\')}'
              Accept: 'application/vnd.github.v3+json'
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

@description('Security Action Group ID')
output securityActionGroupId string = securityActionGroup.id

@description('Security Monitoring Workbook ID')
output securityWorkbookId string = securityMonitoringWorkbook.id

@description('Logic App for Security Testing ID')
output securityTestingLogicAppId string = securityTestingLogicApp.id

@description('All Security Alert IDs')
output securityAlertIds array = [
  keyVaultAccessAlert.id
  cachePerformanceAlert.id
  functionPerformanceAlert.id
]
