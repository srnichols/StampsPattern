// --------------------------------------------------------------------------------------
// CELL Layer Module
// - Deploys isolated application/data resources for a single CELL
// - Intended to be deployed multiple times per region for full isolation
// - Receives dependencies from regional and global layers
// - Network isolation and diagnostic settings are included per CELL
// - Implements host-based (subdomain) routing for tenants via Azure Front Door
// --------------------------------------------------------------------------------------

@description('Azure region for the CELL/Stamp')
param location string

@description('Name for the SQL Server')
param sqlServerName string

@description('SQL admin username')
param sqlAdminUsername string

@secure()
@description('SQL admin password')
param sqlAdminPassword string

@description('Name for the SQL Database')
param sqlDbName string

@description('Name for the Storage Account')
param storageAccountName string

@description('Name for the Cosmos DB account for this CELL/Stamp')
param cosmosDbStampName string

@description('Tags for resources')
param tags object = {}

@description('Azure Availability Zones to use for this CELL/Stamp (e.g., [1,2])')
param zones array = ['1', '2']

@description('Name of the Azure Container Registry for this region')
param containerRegistryName string

@description('Name of the Container App for this CELL')
param containerAppName string

@description('Base domain for the CELL')
param baseDomain string

@description('The resource ID of the central Log Analytics Workspace for diagnostics.')
param globalLogAnalyticsWorkspaceId string

// Create a new Azure Container Registry for the region
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {}
  tags: tags
}

// Front Door backend pools
var frontDoorBackendPools = [
  {
    name: '${containerAppName}-backend'
    backends: [
      {
        address: '${containerAppName}.${baseDomain}'
        httpPort: 80
        httpsPort: 443
      }
    ]
    healthProbeSettings: {
      protocol: 'Https'
      path: '/health'
      intervalInSeconds: 30
    }
  }
]

// Front Door resource definition
resource frontDoor 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: 'myFrontDoor'
  location: 'global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

// Prepare Traffic Manager endpoints using a variable (move for-expression here)
var trafficManagerEndpoints = [
  for cell in frontDoorBackendPools: {
    name: cell.name
    type: 'ExternalEndpoints'
    properties: {
      target: cell.backends[0].address
      endpointStatus: 'Enabled'
    }
  }
]

// Traffic Manager resource definition
resource trafficManager 'Microsoft.Network/trafficManagerProfiles@2022-04-01' = {
  name: 'myTrafficManager'
  location: 'global'
  properties: {
    trafficRoutingMethod: 'Performance'
    dnsConfig: {
      relativeName: 'mytrafficmanager'
      ttl: 30
    }
    monitorConfig: {
      protocol: 'HTTP'
      port: 80
      path: '/health'
    }
    endpoints: trafficManagerEndpoints
  }
}

// Cosmos DB for CELL with zone redundancy enabled for high availability
resource cellCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosDbStampName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: true // Enable zone redundancy for CELL Cosmos DB
      }
    ]
    enableMultipleWriteLocations: false
    databaseAccountOfferType: 'Standard'
  }
  tags: tags
}

// Diagnostic settings for Cosmos DB
resource cosmosDbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${cosmosDbStampName}-diagnostics'
  scope: cellCosmosDb
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      {
        category: 'DataPlaneRequests'
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

// Storage Account for CELL with Premium_ZRS SKU for zone redundancy
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Premium_ZRS' // Use zone-redundant storage
  }
  kind: 'StorageV2'
  properties: {}
  tags: tags
}

// Diagnostic settings for Storage Account
resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${storageAccountName}-diagnostics'
  scope: storageAccount
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
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

// SQL Server for CELL
resource sqlServer 'Microsoft.Sql/servers@2022-11-01' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
  }
}

// Diagnostic settings for SQL Server
resource sqlServerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${sqlServerName}-diagnostics'
  scope: sqlServer
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
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

// Outputs (without secrets)
output acrLoginServer string = containerRegistry.properties.loginServer
output acrUsername string = containerRegistry.listCredentials().username
