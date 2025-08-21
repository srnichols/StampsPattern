
// Orchestrator for global/shared resources in the Hub subscription
// - Creates a central Log Analytics Workspace
// - Deploys globalLayer (DNS, Traffic Manager, Front Door, optional global Functions and Cosmos control plane)

// 📚 Documentation:
// - Architecture Overview: ../docs/ARCHITECTURE_GUIDE.md
// - Deployment Guide: ../docs/DEPLOYMENT_ARCHITECTURE_GUIDE.md
// - Developer Quickstart: ../docs/DEVELOPER_QUICKSTART.md
//
// 📝 Notes for Developers:
// - This file is the main entry point for deploying all Hub-side (shared/global) resources.
// - Naming conventions and resource dependencies are enforced for automation and compliance. See docs for rationale.
// - The deployment expects all required parameters to be set in hub-main.parameters.json.
// - For local development or testing, see the Developer Quickstart for emulator and tool setup.
//
// ⚠️ Prerequisites:
// - Ensure the Hub resource group exists and you have permissions to deploy.
// - The StampsManagementClient app registration must exist in Entra ID; pass its IDs as parameters.
// - Review and update the DNS, Traffic Manager, and Front Door settings as needed.
//
// For more, see the docs above or ask in the project discussions.

targetScope = 'resourceGroup'


// Management Portal App Registration
@description('Application (client) ID for the StampsManagementClient enterprise app registration')
param managementClientAppId string
@description('Entra ID Tenant ID for the StampsManagementClient enterprise app registration')
param managementClientTenantId string

@description('Tags to apply to all resources')
param tags object = {}

@description('Name of the DNS Zone (e.g., stamps.azuresomething.com)')
param dnsZoneName string

@description('Name of the Traffic Manager profile')
param trafficManagerName string

@description('Name of the Front Door profile')
param frontDoorName string

@description('Prefix for Function App names')
param functionAppNamePrefix string = 'fa-stamps'

@description('Prefix for Function App Storage accounts')
param functionStorageNamePrefix string = 'stfastamps'

@description('Base name for the global control plane Cosmos DB account (will be suffixed for uniqueness)')
param globalControlCosmosDbName string = 'cosmos-stamps-control'

@description('Primary region for global Cosmos DB')
param primaryLocation string

@description('Additional regions for global Cosmos DB')
param additionalLocations array = []

@description('Regions to deploy global Function Apps')
param functionAppRegions array = []

@description('Central Log Analytics workspace name')
param logAnalyticsWorkspaceName string

@description('Azure region for the central Log Analytics workspace')
param logAnalyticsWorkspaceLocation string

@description('Enable deployment of global Function Apps (disable if quotas are tight)')
param enableGlobalFunctions bool = true

@description('Enable deployment of global control plane Cosmos DB (disable if quotas are tight)')
param enableGlobalCosmos bool = true

@description('Array of regional Application Gateway endpoints for Traffic Manager')
param regionalEndpoints array = []

@description('Azure Front Door SKU - Standard_AzureFrontDoor or Premium_AzureFrontDoor')
@allowed(['Standard_AzureFrontDoor', 'Premium_AzureFrontDoor'])
param frontDoorSku string = 'Standard_AzureFrontDoor'

// Central Log Analytics Workspace in the Hub subscription
resource law 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: '${logAnalyticsWorkspaceName}-${uniqueString(resourceGroup().id)}'
  location: logAnalyticsWorkspaceLocation
  tags: tags
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

// Deploy the global layer using the Hub LAW for diagnostics
module globalLayer './globalLayer.bicep' = {
  name: 'globalLayer'
  params: {
    dnsZoneName: dnsZoneName
    trafficManagerName: trafficManagerName
    frontDoorName: frontDoorName
    frontDoorSku: frontDoorSku
    globalLogAnalyticsWorkspaceId: law.id
    functionAppNamePrefix: functionAppNamePrefix
    functionStorageNamePrefix: functionStorageNamePrefix
    tags: tags
    functionAppRegions: functionAppRegions
  globalControlCosmosDbName: '${toLower(globalControlCosmosDbName)}-${uniqueString(resourceGroup().id, deployment().name)}'
    primaryLocation: primaryLocation
    additionalLocations: additionalLocations
  cosmosZoneRedundant: false
    enableGlobalFunctions: enableGlobalFunctions
    enableGlobalCosmos: enableGlobalCosmos
    regionalEndpoints: regionalEndpoints
  }
}

output logAnalyticsWorkspaceId string = law.id
output message string = 'Hub global resources deployed'
output trafficManagerFqdn string = globalLayer.outputs.trafficManagerFqdn
output frontDoorProfileName string = globalLayer.outputs.frontDoorProfileName
output frontDoorEndpointHostname string = globalLayer.outputs.frontDoorEndpointHostname
output dnsZoneName string = globalLayer.outputs.dnsZoneName
