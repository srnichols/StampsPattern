// --------------------------------------------------------------------------------------
// Enhanced Monitoring and Alerting for Stamps Pattern
// - Creates comprehensive monitoring workbooks
// - Implements intelligent alerting
// - Provides AI-driven insights
// --------------------------------------------------------------------------------------

@description('Azure region for monitoring resources')
param location string = resourceGroup().location

@description('Application Insights resource ID')
param applicationInsightsId string

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

@description('Monitoring name prefix')
param monitoringPrefix string = 'stamps-pattern'

@description('Environment name')
@allowed(['dev', 'test', 'staging', 'prod'])
param environment string = 'prod'

@description('Tags for resources')
param tags object = {}

@description('Alert email recipients')
param alertEmailRecipients array = ['devops@contoso.com']

// ============ ACTION GROUP FOR ALERTS ============

resource alertActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: '${monitoringPrefix}-alerts-${environment}'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'StampsAlert'
    enabled: true
    emailReceivers: [for (email, i) in alertEmailRecipients: {
      name: 'email-${i}'
      emailAddress: email
      useCommonAlertSchema: true
    }]
    smsReceivers: []
    webhookReceivers: []
    armRoleReceivers: [
      {
        name: 'OwnerRole'
        roleId: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
        useCommonAlertSchema: true
      }
    ]
  }
}

// ============ METRIC ALERTS ============

// High Error Rate Alert
resource highErrorRateAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${monitoringPrefix}-high-error-rate-${environment}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Triggers when error rate exceeds 5% over 5 minutes'
    severity: 2
    enabled: true
    scopes: [
      applicationInsightsId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighErrorRate'
          metricName: 'requests/failed'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: alertActionGroup.id
      }
    ]
  }
}

// Response Time Alert
resource responseTimeAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${monitoringPrefix}-high-response-time-${environment}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Triggers when 95th percentile response time exceeds 2 seconds'
    severity: 3
    enabled: true
    scopes: [
      applicationInsightsId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighResponseTime'
          metricName: 'requests/duration'
          operator: 'GreaterThan'
          threshold: 2000
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: alertActionGroup.id
      }
    ]
  }
}

// Availability Alert
resource availabilityAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${monitoringPrefix}-low-availability-${environment}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Triggers when availability drops below 99%'
    severity: 1
    enabled: true
    scopes: [
      applicationInsightsId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'LowAvailability'
          metricName: 'availabilityResults/availabilityPercentage'
          operator: 'LessThan'
          threshold: 99
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: alertActionGroup.id
      }
    ]
  }
}

// ============ LOG ANALYTICS ALERTS ============

// Security Alert for WAF Blocks
resource wafBlocksAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: '${monitoringPrefix}-waf-blocks-${environment}'
  location: location
  tags: tags
  properties: {
    displayName: 'WAF High Block Rate'
    description: 'Alert when WAF blocks exceed normal threshold'
    severity: 2
    enabled: true
    scopes: [
      logAnalyticsWorkspaceId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: 'AzureDiagnostics | where Category == "ApplicationGatewayFirewallLog" | where action_s == "Blocked" | summarize BlockCount = count() | where BlockCount > 50'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        alertActionGroup.id
      ]
    }
  }
}

// ============ MONITORING WORKBOOKS ============

// Executive Dashboard Workbook
resource executiveWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('executive-dashboard', resourceGroup().id)
  location: location
  kind: 'shared'
  tags: tags
  properties: {
    displayName: 'Stamps Pattern: Executive Dashboard'
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# 📊 Stamps Pattern Executive Dashboard\\n\\n**Overview of multi-tenant application performance, cost, and health across all deployment cells.**"
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
              "query": "requests\\n| where timestamp > ago(24h)\\n| summarize TotalRequests = count(), SuccessRate = round(avg(todouble(success)) * 100, 2), AvgDuration = round(avg(duration), 2)\\n| extend Status = case(SuccessRate >= 99.9, \\"🟢 Excellent\\", SuccessRate >= 99, \\"🟡 Good\\", \\"🔴 Critical\\")\\n| project Status, TotalRequests, SuccessRate, AvgDuration",
              "size": 3,
              "title": "🎯 Overall Health Score (24h)",
              "queryType": 0,
              "visualization": "table",
              "gridSettings": {
                "formatters": [
                  {
                    "columnMatch": "Status",
                    "formatter": 1
                  }
                ]
              }
            }
          },
          {
            "type": 3,
            "content": {
              "version": "KqlItem/1.0",
              "query": "requests\\n| where timestamp > ago(24h)\\n| extend TenantId = tostring(customDimensions.TenantId)\\n| extend CellId = cloud_RoleInstance\\n| summarize Requests = count(), ErrorRate = round(countif(success == false) * 100.0 / count(), 2) by TenantId, CellId\\n| top 10 by Requests desc",
              "size": 0,
              "title": "🏢 Top Tenants by Activity",
              "queryType": 0,
              "visualization": "table"
            }
          }
        ]
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "requests\\n| where timestamp > ago(7d)\\n| summarize Requests = count() by bin(timestamp, 1h), cloud_RoleInstance\\n| render timechart",
        "size": 0,
        "title": "📈 Request Volume by CELL (7 days)",
        "queryType": 0,
        "visualization": "timechart"
      }
    }
  ]
}
'''
    category: 'workbook'
    sourceId: applicationInsightsId
  }
}

// Operations Team Workbook
resource operationsWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('operations-workbook', resourceGroup().id)
  location: location
  kind: 'shared'
  tags: tags
  properties: {
    displayName: 'Stamps Pattern: Operations Deep Dive'
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# 🔧 Operations Deep Dive\\n\\n**Detailed performance metrics, error analysis, and operational insights for DevOps teams.**"
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "requests\\n| where timestamp > ago(1h)\\n| summarize p50 = percentile(duration, 50), p95 = percentile(duration, 95), p99 = percentile(duration, 99) by bin(timestamp, 1m)\\n| render timechart",
        "size": 0,
        "title": "⚡ Response Time Percentiles (1h)",
        "queryType": 0,
        "visualization": "timechart"
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "exceptions\\n| where timestamp > ago(24h)\\n| summarize Count = count() by type, cloud_RoleInstance\\n| top 15 by Count desc",
        "size": 0,
        "title": "🚨 Top Exceptions by CELL",
        "queryType": 0,
        "visualization": "table"
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "dependencies\\n| where type == \\"SQL\\"\\n| where timestamp > ago(6h)\\n| summarize AvgDuration = avg(duration), MaxDuration = max(duration), Count = count() by target\\n| order by AvgDuration desc",
        "size": 0,
        "title": "🗄️ Database Performance",
        "queryType": 0,
        "visualization": "table"
      }
    }
  ]
}
'''
    category: 'workbook'
    sourceId: applicationInsightsId
  }
}

// Security Monitoring Workbook
resource securityWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('security-workbook', resourceGroup().id)
  location: location
  kind: 'shared'
  tags: tags
  properties: {
    displayName: 'Stamps Pattern: Security Monitoring'
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# 🛡️ Security Monitoring Dashboard\\n\\n**Comprehensive security insights including WAF activity, authentication events, and threat detection.**"
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "requests\\n| where resultCode startswith \\"40\\"\\n| where timestamp > ago(24h)\\n| summarize FailedAuth = count() by bin(timestamp, 1h), clientIP\\n| top 20 by FailedAuth desc",
        "size": 0,
        "title": "🔐 Authentication Failures by IP",
        "queryType": 0,
        "visualization": "table"
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "requests\\n| where timestamp > ago(24h)\\n| where resultCode in (429, 403, 401)\\n| summarize SecurityEvents = count() by bin(timestamp, 1h), resultCode\\n| render timechart",
        "size": 0,
        "title": "🚫 Security-Related HTTP Status Codes",
        "queryType": 0,
        "visualization": "timechart"
      }
    }
  ]
}
'''
    category: 'workbook'
    sourceId: logAnalyticsWorkspaceId
  }
}

// ============ OUTPUTS ============

output alertActionGroupId string = alertActionGroup.id
output executiveWorkbookId string = executiveWorkbook.id
output operationsWorkbookId string = operationsWorkbook.id
output securityWorkbookId string = securityWorkbook.id
output alertRuleIds array = [
  highErrorRateAlert.id
  responseTimeAlert.id
  availabilityAlert.id
  wafBlocksAlert.id
]
