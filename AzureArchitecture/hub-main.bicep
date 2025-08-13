// Orchestrator for global/shared resources in the Hub subscription
// - Creates a central Log Analytics Workspace
// - Deploys globalLayer (DNS, Traffic Manager, Front Door, optional global Functions and Cosmos control plane)

targetScope = 'resourceGroup'

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
