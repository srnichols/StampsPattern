// Enhanced Monitoring and Alerting Configuration
// This extends the existing monitoring with cache performance and security alerts

@description('Location for regional resources')
param location string = resourceGroup().location

@description('Environment identifier')
param environment string = 'dev'

@description('Unique resource token')
param resourceToken string = take(uniqueString(resourceGroup().id), 6)

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string


@description('Redis Cache resource ID')
param redisCacheId string

@description('Function App resource ID')
param functionAppId string

@description('Cosmos DB account resource ID')
param cosmosDbId string

@description('Alert notification email')
param alertEmail string = 'ops@sdp-saas.com'

// ============ ACTION GROUPS ============

// Performance Action Group
resource performanceActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-performance-${resourceToken}'
  location: 'global'
  properties: {
    groupShortName: 'PerfAlert'
    enabled: true
    emailReceivers: [
      {
        name: 'Performance Team'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
    smsReceivers: []
    webhookReceivers: [
      {
        name: 'Teams Webhook'
        serviceUri: 'https://outlook.office.com/webhook/your-teams-webhook-url'
        useCommonAlertSchema: true
      }
    ]
  }
}

// Cache Performance Action Group
resource cacheActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-cache-${resourceToken}'
  location: 'global'
  properties: {
    groupShortName: 'CacheAlert'
    enabled: true
    emailReceivers: [
      {
        name: 'Cache Team'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

// ============ CACHE PERFORMANCE ALERTS ============

// Redis Cache Hit Ratio Alert
resource cacheHitRatioAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Redis Cache Hit Ratio Low'
  location: 'global'
  properties: {
    description: 'Alert when Redis cache hit ratio drops below 80%'
    severity: 2
    enabled: true
    scopes: [redisCacheId]
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
        actionGroupId: cacheActionGroup.id
      }
    ]
  }
}

// Redis Memory Usage Alert
resource cacheMemoryAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Redis Memory Usage High'
  location: 'global'
  properties: {
    description: 'Alert when Redis memory usage exceeds 85%'
    severity: 1
    enabled: true
    scopes: [redisCacheId]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'High memory usage'
          metricName: 'UsedMemoryPercentage'
          operator: 'GreaterThan'
          threshold: 85
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: cacheActionGroup.id
      }
    ]
  }
}

// ============ FUNCTION APP PERFORMANCE ALERTS ============

// Function Response Time Alert
resource functionResponseTimeAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Function App High Response Time'
  location: 'global'
  properties: {
    description: 'Alert when Function App average response time exceeds 200ms'
    severity: 2
    enabled: true
    scopes: [functionAppId]
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
        actionGroupId: performanceActionGroup.id
      }
    ]
  }
}

// Function Error Rate Alert
resource functionErrorRateAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Function App High Error Rate'
  location: 'global'
  properties: {
    description: 'Alert when Function App error rate exceeds 5%'
    severity: 1
    enabled: true
    scopes: [functionAppId]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'High error rate'
          metricName: 'Http5xx'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: performanceActionGroup.id
      }
    ]
  }
}

// ============ COSMOS DB PERFORMANCE ALERTS ============

// Cosmos DB High RU Consumption Alert
resource cosmosDbRuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Cosmos DB High RU Consumption'
  location: 'global'
  properties: {
    description: 'Alert when Cosmos DB RU consumption exceeds 80%'
    severity: 2
    enabled: true
    scopes: [cosmosDbId]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'High RU consumption'
          metricName: 'NormalizedRUConsumption'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Maximum'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: performanceActionGroup.id
      }
    ]
  }
}

// Cosmos DB Throttling Alert
resource cosmosDbThrottlingAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Cosmos DB Throttling Detected'
  location: 'global'
  properties: {
    description: 'Alert when Cosmos DB requests are being throttled'
    severity: 1
    enabled: true
    scopes: [cosmosDbId]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Throttling detected'
          metricName: 'UserErrors'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'StatusCode'
              operator: 'Include'
              values: ['429']
            }
          ]
        }
      ]
    }
    actions: [
      {
        actionGroupId: performanceActionGroup.id
      }
    ]
  }
}

// ============ OPERATIONAL INSIGHTS WORKBOOK ============

resource operationalInsightsWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: 'operational-insights-${resourceToken}'
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Azure Stamps Pattern - Operational Insights'
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# Azure Stamps Pattern - Operational Dashboard\\n\\n## Performance & Cache Metrics\\n- Redis cache performance monitoring\\n- Function app response times\\n- Cosmos DB performance\\n- Tenant distribution analytics"
      }
    },
    {
      "type": 12,
      "content": {
        "version": "NotebookGroup/1.0",
        "groupType": "editable",
        "title": "Cache Performance",
        "items": [
          {
            "type": 3,
            "content": {
              "version": "KqlItem/1.0",
              "query": "AzureMetrics\\n| where ResourceProvider == \\"MICROSOFT.CACHE\\"\\n| where MetricName == \\"CacheHitRate\\"\\n| where TimeGenerated > ago(24h)\\n| summarize avg(Average) by bin(TimeGenerated, 1h)\\n| render timechart",
              "size": 0,
              "title": "Cache Hit Rate (24h)",
              "queryType": 0,
              "resourceType": "microsoft.operationalinsights/workspaces"
            }
          },
          {
            "type": 3,
            "content": {
              "version": "KqlItem/1.0",
              "query": "AzureMetrics\\n| where ResourceProvider == \\"MICROSOFT.CACHE\\"\\n| where MetricName == \\"UsedMemoryPercentage\\"\\n| where TimeGenerated > ago(24h)\\n| summarize avg(Average) by bin(TimeGenerated, 1h)\\n| render timechart",
              "size": 0,
              "title": "Memory Usage (24h)",
              "queryType": 0,
              "resourceType": "microsoft.operationalinsights/workspaces"
            }
          }
        ]
      }
    },
    {
      "type": 12,
      "content": {
        "version": "NotebookGroup/1.0",
        "groupType": "editable",
        "title": "Function App Performance",
        "items": [
          {
            "type": 3,
            "content": {
              "version": "KqlItem/1.0",
              "query": "AzureDiagnostics\\n| where Category == \\"FunctionAppLogs\\"\\n| where TimeGenerated > ago(24h)\\n| summarize avg(DurationMs) by bin(TimeGenerated, 1h), FunctionName\\n| render timechart",
              "size": 0,
              "title": "Function Response Times (24h)",
              "queryType": 0,
              "resourceType": "microsoft.operationalinsights/workspaces"
            }
          },
          {
            "type": 3,
            "content": {
              "version": "KqlItem/1.0",
              "query": "AzureDiagnostics\\n| where Category == \\"FunctionAppLogs\\"\\n| where Level == \\"Error\\"\\n| where TimeGenerated > ago(24h)\\n| summarize Count = count() by bin(TimeGenerated, 1h)\\n| render timechart",
              "size": 0,
              "title": "Error Rate (24h)",
              "queryType": 0,
              "resourceType": "microsoft.operationalinsights/workspaces"
            }
          }
        ]
      }
    },
    {
      "type": 12,
      "content": {
        "version": "NotebookGroup/1.0",
        "groupType": "editable",
        "title": "Tenant Analytics",
        "items": [
          {
            "type": 3,
            "content": {
              "version": "KqlItem/1.0",
              "query": "traces\\n| where message contains \\"TenantCreated\\"\\n| where timestamp > ago(24h)\\n| extend TenantTier = tostring(customDimensions[\\"TenantTier\\"])\\n| summarize Count = count() by TenantTier\\n| render piechart",
              "size": 0,
              "title": "New Tenants by Tier (24h)",
              "queryType": 0,
              "resourceType": "microsoft.insights/components"
            }
          },
          {
            "type": 3,
            "content": {
              "version": "KqlItem/1.0",
              "query": "traces\\n| where message contains \\"TenantRouted\\"\\n| where timestamp > ago(24h)\\n| extend Region = tostring(customDimensions[\\"Region\\"])\\n| summarize Count = count() by Region\\n| render columnchart",
              "size": 0,
              "title": "Tenant Distribution by Region (24h)",
              "queryType": 0,
              "resourceType": "microsoft.insights/components"
            }
          }
        ]
      }
    }
  ]
}
'''
    category: 'workbook'
    sourceId: logAnalyticsWorkspaceId
  }
}

// ============ CUSTOM LOG QUERIES ============

// Saved query for cache performance analysis
resource cachePerformanceQuery 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  name: '${last(split(logAnalyticsWorkspaceId, '/'))}/cache-performance-analysis'
  properties: {
    displayName: 'Cache Performance Analysis'
    category: 'Performance'
    query: '''
AzureMetrics
| where ResourceProvider == "MICROSOFT.CACHE"
| where TimeGenerated > ago(24h)
| where MetricName in ("CacheHitRate", "UsedMemoryPercentage", "ConnectedClients")
| summarize 
    AvgCacheHitRate = avg(iff(MetricName == "CacheHitRate", Average, real(null))),
    AvgMemoryUsage = avg(iff(MetricName == "UsedMemoryPercentage", Average, real(null))),
    AvgConnectedClients = avg(iff(MetricName == "ConnectedClients", Average, real(null)))
    by bin(TimeGenerated, 1h)
| project TimeGenerated, AvgCacheHitRate, AvgMemoryUsage, AvgConnectedClients
| order by TimeGenerated desc
'''
    tags: [
      {
        name: 'Environment'
        value: environment
      }
      {
        name: 'Component'
        value: 'Cache'
      }
    ]
  }
}

// Saved query for JWT validation performance
resource jwtPerformanceQuery 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  name: '${last(split(logAnalyticsWorkspaceId, '/'))}/jwt-validation-performance'
  properties: {
    displayName: 'JWT Validation Performance'
    category: 'Performance'
    query: '''
traces
| where message contains "JWT validation"
| where timestamp > ago(24h)
| extend Duration = todouble(customDimensions["Duration"])
| extend CacheHit = tobool(customDimensions["CacheHit"])
| summarize 
    AvgDuration = avg(Duration),
    P95Duration = percentile(Duration, 95),
    P99Duration = percentile(Duration, 99),
    CacheHitRate = avg(iff(CacheHit, 1.0, 0.0)) * 100
    by bin(timestamp, 1h)
| project timestamp, AvgDuration, P95Duration, P99Duration, CacheHitRate
| order by timestamp desc
'''
    tags: [
      {
        name: 'Environment'
        value: environment
      }
      {
        name: 'Component'
        value: 'Authentication'
      }
    ]
  }
}

// ============ OUTPUTS ============

@description('Performance Action Group ID')
output performanceActionGroupId string = performanceActionGroup.id

@description('Cache Action Group ID')
output cacheActionGroupId string = cacheActionGroup.id

@description('Operational Insights Workbook ID')
output operationalWorkbookId string = operationalInsightsWorkbook.id

@description('All Alert Rule IDs')
output alertRuleIds array = [
  cacheHitRatioAlert.id
  cacheMemoryAlert.id
  functionResponseTimeAlert.id
  functionErrorRateAlert.id
  cosmosDbRuAlert.id
  cosmosDbThrottlingAlert.id
]
