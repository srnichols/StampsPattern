@description('Name of the API Management instance')
param apimName string

@description('Azure region for the APIM instance')
param location string

@description('APIM Publisher Email')
param apimPublisherEmail string

@description('APIM Publisher Name')
param apimPublisherName string

@description('APIM SKU name')
param apimSkuName string = 'Developer'

@description('Tags for resource management')
param tags object = {}

@description('The resource ID of the central Log Analytics Workspace for diagnostics')
param globalLogAnalyticsWorkspaceId string

// Minimal APIM instance module used for per-region instances in demo topology
resource apimInstance 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: apimSkuName
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    virtualNetworkType: 'None'
    additionalLocations: []
    // Keep customProperties minimal here; parent can set additional settings if required
  }
  tags: tags
}

// Diagnostic settings (optional) - only reference the workspaceId if provided
resource apimDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(globalLogAnalyticsWorkspaceId)) {
  name: '${apimName}-diagnostics'
  scope: apimInstance
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output gatewayUrl string = apimInstance.properties.gatewayUrl
output developerPortalUrl string = apimInstance.properties.developerPortalUrl
output managementApiUrl string = apimInstance.properties.managementApiUrl
output id string = apimInstance.id
