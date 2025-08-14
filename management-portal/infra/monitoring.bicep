// Azure Monitoring Configuration for Stamps Management Portal

@description('Location for resources')
param location string = resourceGroup().location

@description('Application Insights name')
param appInsightsName string

@description('Log Analytics Workspace name')  
param logAnalyticsWorkspaceName string

@description('Common tags for resources')
param tags object = {}

// Get existing resources
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

// Alert Rules for Critical Issues
resource highErrorRateAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-portal-high-error-rate'
  location: 'global'
  properties: {
    description: 'Alert when error rate is high in the portal'
    severity: 2
    enabled: true
    scopes: [
      appInsights.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighErrorRate'
          metricName: 'requests/failed'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: []
  }
  tags: tags
}

resource highResponseTimeAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-portal-high-response-time'
  location: 'global'
  properties: {
    description: 'Alert when response time is high'
    severity: 3
    enabled: true
    scopes: [
      appInsights.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighResponseTime'
          metricName: 'requests/duration'
          operator: 'GreaterThan'
          threshold: 5000 // 5 seconds in milliseconds
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: []
  }
  tags: tags
}

// Output URLs for easy access
output appInsightsUrl string = 'https://portal.azure.com/#@${tenant().tenantId}/resource${appInsights.id}/overview'
output logAnalyticsUrl string = 'https://portal.azure.com/#@${tenant().tenantId}/resource${logAnalyticsWorkspace.id}/logs'
