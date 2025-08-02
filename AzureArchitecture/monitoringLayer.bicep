// --------------------------------------------------------------------------------------
// Module: monitoringLayer
// Purpose: Provisions monitoring resources such as Log Analytics Workspace for centralized logging and monitoring.
//          Outputs the workspace resource ID for integration with other modules.
// --------------------------------------------------------------------------------------

@description('Azure region for the monitoring resources')
param location string // The Azure region where monitoring resources will be deployed.

@description('Name of the Log Analytics Workspace (must be globally unique)')
param logAnalyticsWorkspaceName string // Unique name for the Log Analytics Workspace.

@description('Retention period (in days) for logs')
param retentionInDays int // Number of days to retain logs in the workspace.

@description('Tags for resource management')
param tags object = {} // Optional tags for resource organization and cost tracking.

// Deploy Log Analytics Workspace for monitoring and diagnostics.
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: '${logAnalyticsWorkspaceName}-${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  properties: {
    retentionInDays: retentionInDays // Set log retention period.
    sku: {
      name: 'PerGB2018' // Standard pay-as-you-go SKU.
    }
  }
}

// Output the workspace resource ID for use in other modules.
output logAnalyticsWorkspaceId string = logAnalytics.id

// Add additional monitoring resources (alerts, solutions, etc.) as needed.
