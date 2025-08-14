targetScope = 'subscription'

@description('The Azure region where all resources will be deployed')
param location string = 'westus2'

@description('The environment name used for resource naming')
param environmentName string

@description('The resource group name')
param resourceGroupName string = 'rg-${environmentName}'

// Generate resource token for unique naming
var resourceToken = uniqueString(subscription().id, location, environmentName)

@description('The name of the Cosmos DB account')
param cosmosAccountName string = ''

@description('The name of the Container Apps environment')
param containerAppsEnvironmentName string = ''

@description('The name of the Container Registry')
param containerRegistryName string = ''

@description('The name of the Log Analytics workspace')
param logAnalyticsWorkspaceName string = ''

@description('The name of the Application Insights component')
param appInsightsName string = ''

// Use generated names if not provided
var actualCosmosAccountName = empty(cosmosAccountName) ? 'cosmos-${resourceToken}' : cosmosAccountName
var actualContainerAppsEnvironmentName = empty(containerAppsEnvironmentName) ? 'cae-${resourceToken}' : containerAppsEnvironmentName
var actualContainerRegistryName = empty(containerRegistryName) ? 'cr${resourceToken}' : containerRegistryName
var actualLogAnalyticsWorkspaceName = empty(logAnalyticsWorkspaceName) ? 'law-${resourceToken}' : logAnalyticsWorkspaceName
var actualAppInsightsName = empty(appInsightsName) ? 'ai-${resourceToken}' : appInsightsName

// Common tags for all resources
var tags = {
  'azd-env-name': environmentName
  project: 'stamps-management-portal'
  environment: 'production'
}

// Resource group for the management portal
resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module managementPortal 'management-portal.bicep' = {
  scope: resourceGroup
  name: 'managementPortal'
  params: {
    location: location
    cosmosAccountName: actualCosmosAccountName
    containerAppsEnvironmentName: actualContainerAppsEnvironmentName
    containerRegistryName: actualContainerRegistryName
    logAnalyticsWorkspaceName: actualLogAnalyticsWorkspaceName
    appInsightsName: actualAppInsightsName
    tags: tags
  }
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_RESOURCE_GROUP string = resourceGroup.name
output RESOURCE_GROUP_ID string = resourceGroup.id
output AZURE_PORTAL_URL string = managementPortal.outputs.portalUrl
output AZURE_DAB_URL string = managementPortal.outputs.dabUrl
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = managementPortal.outputs.containerRegistryLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = managementPortal.outputs.containerRegistryName
