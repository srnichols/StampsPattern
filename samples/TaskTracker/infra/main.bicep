targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Id of the user or app to assign application roles')
param principalId string = ''

// Optional parameters for existing resources
param cosmosAccountName string = ''
param cosmosDbName string = ''
param storageAccountName string = ''
param containerAppsEnvironmentName string = ''
param containerRegistryName string = ''
param logAnalyticsName string = ''

// Generate unique resource names
var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Container Apps Environment
module containerApps 'core/host/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  scope: rg
  params: {
    name: !empty(containerAppsEnvironmentName) ? containerAppsEnvironmentName : '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
  }
}

// Container Registry
module containerRegistry 'core/host/container-registry.bicep' = {
  name: 'container-registry'
  scope: rg
  params: {
    name: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
  }
}

// Log Analytics Workspace & Application Insights
module monitoring 'core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
  }
}

// Cosmos DB
module cosmos 'core/database/cosmos/sql/cosmos-sql-db.bicep' = {
  name: 'cosmos-sql'
  scope: rg
  params: {
    accountName: !empty(cosmosAccountName) ? cosmosAccountName : '${abbrs.documentDBDatabaseAccounts}${resourceToken}'
    databaseName: !empty(cosmosDbName) ? cosmosDbName : 'TaskTrackerDb'
    location: location
    tags: tags
    containers: [
      {
        name: 'Tasks'
        partitionKey: '/tenantId'
        maxThroughput: 1000
      }
      {
        name: 'Categories'
        partitionKey: '/tenantId'
        maxThroughput: 400
      }
      {
        name: 'Tags'
        partitionKey: '/tenantId'
        maxThroughput: 400
      }
      {
        name: 'Tenants'
        partitionKey: '/id'
        maxThroughput: 400
      }
      {
        name: 'Users'
        partitionKey: '/tenantId'
        maxThroughput: 400
      }
    ]
  }
}

// Storage Account for blob storage
module storage 'core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    containers: [
      {
        name: 'task-attachments'
        publicAccess: 'None'
      }
    ]
  }
}

// Redis Cache
module redis 'core/database/redis/redis.bicep' = {
  name: 'redis'
  scope: rg
  params: {
    name: '${abbrs.cacheRedis}${resourceToken}'
    location: location
    tags: tags
  }
}

// The main TaskTracker application
module tasktracker 'app/tasktracker.bicep' = {
  name: 'tasktracker'
  scope: rg
  params: {
    name: '${abbrs.appContainerApps}tasktracker-${resourceToken}'
    location: location
    tags: tags
    identityName: '${abbrs.managedIdentityUserAssignedIdentities}tasktracker-${resourceToken}'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    containerRegistryName: containerRegistry.outputs.name
    cosmosAccountName: cosmos.outputs.accountName
    cosmosDatabaseName: cosmos.outputs.databaseName
    storageAccountName: storage.outputs.name
    redisCacheName: redis.outputs.name
    exists: false
  }
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name

output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = monitoring.outputs.logAnalyticsWorkspaceName

output AZURE_COSMOS_CONNECTION_STRING_KEY string = cosmos.outputs.connectionStringKey
output AZURE_COSMOS_DATABASE_NAME string = cosmos.outputs.databaseName

output AZURE_STORAGE_ACCOUNT_NAME string = storage.outputs.name
output AZURE_STORAGE_ACCOUNT_KEY string = storage.outputs.primaryKey

output AZURE_REDIS_CONNECTION_STRING string = redis.outputs.connectionString

output SERVICE_TASKTRACKER_IDENTITY_PRINCIPAL_ID string = tasktracker.outputs.identityPrincipalId
output SERVICE_TASKTRACKER_NAME string = tasktracker.outputs.name
output SERVICE_TASKTRACKER_URI string = tasktracker.outputs.uri
