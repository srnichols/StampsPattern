// --------------------------------------------------------------------------------------
// AI-Driven Cost Optimization for Stamps Pattern
// - Implements intelligent cost tracking and optimization
// - Provides predictive scaling recommendations
// - Enables automated cost control measures
// --------------------------------------------------------------------------------------

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Cost optimization name prefix')
param costOptimizationPrefix string = 'stamps-cost-opt'

@description('Environment name')
@allowed(['dev', 'test', 'staging', 'prod'])
param environment string = 'prod'

@description('Tags for resources')
param tags object = {}

@description('Application Insights resource ID')
param applicationInsightsId string

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

@description('Storage Account ID for cost data')
param storageAccountId string

@description('Cost threshold for alerts (USD)')
param costThreshold int = 1000

// ============ COST MANAGEMENT COMPONENTS ============

// Cost Anomaly Detection using Automation Account
resource costOptimizationAutomation 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: '${costOptimizationPrefix}-automation-${environment}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'Basic'
    }
    encryption: {
      keySource: 'Microsoft.Automation'
    }
  }
}

// Managed Identity for Cost Optimization
resource costOptimizationIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${costOptimizationPrefix}-identity-${environment}'
  location: location
  tags: tags
}

// ============ COST TRACKING AUTOMATION ============

// Cost Optimization Variables
resource costThresholdVariable 'Microsoft.Automation/automationAccounts/variables@2020-01-13-preview' = {
  parent: costOptimizationAutomation
  name: 'CostThreshold'
  properties: {
    description: 'Monthly cost threshold for alerts'
    value: '"${costThreshold}"'
    isEncrypted: false
  }
}

resource environmentVariable 'Microsoft.Automation/automationAccounts/variables@2020-01-13-preview' = {
  parent: costOptimizationAutomation
  name: 'Environment'
  properties: {
    description: 'Current environment name'
    value: '"${environment}"'
    isEncrypted: false
  }
}

// ============ INTELLIGENT SCALING LOGIC ============

// Logic App for Predictive Scaling
resource predictiveScalingLogicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: '${costOptimizationPrefix}-predictive-scaling-${environment}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${costOptimizationIdentity.id}': {}
    }
  }
  properties: {
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        applicationInsightsId: {
          type: 'string'
          defaultValue: applicationInsightsId
        }
        logAnalyticsWorkspaceId: {
          type: 'string'
          defaultValue: logAnalyticsWorkspaceId
        }
      }
      triggers: {
        recurrence: {
          type: 'Recurrence'
          recurrence: {
            frequency: 'Hour'
            interval: 1
          }
        }
      }
      actions: {
        'Get-Performance-Metrics': {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: 'https://api.applicationinsights.io/v1/apps/${last(split(applicationInsightsId, '/'))}/query'
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              query: 'requests | where timestamp > ago(1h) | summarize RequestCount = count(), AvgDuration = avg(duration), ErrorRate = countif(success == false) * 100.0 / count() by cloud_RoleInstance'
            }
            authentication: {
              type: 'ManagedServiceIdentity'
              identity: costOptimizationIdentity.id
            }
          }
        }
        'Analyze-Scaling-Requirements': {
          type: 'Compose'
          inputs: {
            scalingRecommendations: {
              scaleUp: '@greater(body(\'Get-Performance-Metrics\')?[\'tables\']?[0]?[\'rows\']?[0]?[1], 5000)'
              scaleDown: '@less(body(\'Get-Performance-Metrics\')?[\'tables\']?[0]?[\'rows\']?[0]?[1], 1000)'
              timestamp: '@utcNow()'
            }
          }
          runAfter: {
            'Get-Performance-Metrics': ['Succeeded']
          }
        }
        'Send-Scaling-Recommendations': {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: 'https://${last(split(logAnalyticsWorkspaceId, '/'))}.ods.opinsights.azure.com/api/logs?api-version=2016-04-01'
            headers: {
              'Content-Type': 'application/json'
              'Log-Type': 'ScalingRecommendations'
            }
            body: '@outputs(\'Analyze-Scaling-Requirements\')'
            authentication: {
              type: 'ManagedServiceIdentity'
              identity: costOptimizationIdentity.id
            }
          }
          runAfter: {
            'Analyze-Scaling-Requirements': ['Succeeded']
          }
        }
      }
    }
  }
}

// ============ COST OPTIMIZATION WORKBOOK ============

resource costOptimizationWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('cost-optimization-workbook', resourceGroup().id)
  location: location
  kind: 'shared'
  tags: tags
  properties: {
    displayName: 'Stamps Pattern: Cost Optimization Intelligence'
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# 💰 Cost Optimization Intelligence\\n\\n**AI-driven insights for optimizing costs across the Stamps Pattern deployment.**"
      }
    },
    {
      "type": 12,
      "content": {
        "version": "NotebookGroup/1.0",
        "groupType": "editable",
        "items": [
          {
            "type": 3,
            "content": {
              "version": "KqlItem/1.0",
              "query": "customMetrics\\n| where name == \\"CostPerTenant\\"\\n| extend TenantId = tostring(customDimensions.TenantId)\\n| extend CellId = tostring(customDimensions.CellId)\\n| summarize AvgCost = avg(value), TotalCost = sum(value) by TenantId, CellId\\n| top 20 by TotalCost desc",
              "size": 0,
              "title": "💸 Cost by Tenant and CELL",
              "queryType": 0,
              "visualization": "table",
              "gridSettings": {
                "formatters": [
                  {
                    "columnMatch": "TotalCost",
                    "formatter": 1,
                    "formatOptions": {
                      "customColumnWidthSetting": "100px"
                    }
                  }
                ]
              }
            }
          },
          {
            "type": 3,
            "content": {
              "version": "KqlItem/1.0",
              "query": "requests\\n| where timestamp > ago(7d)\\n| extend TenantId = tostring(customDimensions.TenantId)\\n| summarize RequestCount = count(), AvgDuration = avg(duration) by TenantId, bin(timestamp, 1d)\\n| render timechart",
              "size": 0,
              "title": "Resource Utilization Trends",
              "queryType": 0,
              "visualization": "timechart"
            }
          }
        ]
      }
    },
    {
      "type": 1,
      "content": {
        "json": "## 🎯 Cost Optimization Recommendations\\n\\n### Automated Insights:\\n- **Right-sizing**: Monitor CPU and memory utilization to identify over-provisioned resources\\n- **Predictive Scaling**: Use AI models to predict traffic patterns and scale proactively\\n- **Tenant Cost Allocation**: Track per-tenant costs for accurate billing and optimization\\n- **Idle Resource Detection**: Identify and decommission unused resources automatically\\n\\n### Key Metrics:\\n- **Cost per Request**: Track cost efficiency across tenants\\n- **Resource Utilization**: Monitor CPU, memory, and storage usage\\n- **Scaling Events**: Analyze auto-scaling patterns for optimization opportunities"
      }
    }
  ]
}
'''
    category: 'workbook'
    sourceId: logAnalyticsWorkspaceId
  }
}

// ============ STORAGE LIFECYCLE OPTIMIZATION ============

// Lifecycle Management Policy for Cost Optimization
resource storageLifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    policy: {
      rules: [
        {
          name: 'ArchiveOldLogs'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['logs/', 'diagnostics/']
            }
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: 30
                }
                tierToArchive: {
                  daysAfterModificationGreaterThan: 90
                }
                delete: {
                  daysAfterModificationGreaterThan: 2555 // 7 years retention
                }
              }
            }
          }
        }
        {
          name: 'DeleteTempFiles'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['temp/', 'tmp/']
            }
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: 7
                }
              }
            }
          }
        }
      ]
    }
  }
}

// Reference to existing storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: last(split(storageAccountId, '/'))
}

// ============ OUTPUTS ============

output costOptimizationAutomationId string = costOptimizationAutomation.id
output costOptimizationIdentityId string = costOptimizationIdentity.id
output predictiveScalingLogicAppId string = predictiveScalingLogicApp.id
output costOptimizationWorkbookId string = costOptimizationWorkbook.id
output storageLifecyclePolicyId string = storageLifecyclePolicy.id
