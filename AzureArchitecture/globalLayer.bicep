// --------------------------------------------------------------------------------------
// Module: globalLayer
// Purpose: Provisions global/shared resources such as DNS Zone, Traffic Manager, and Front Door.
//          Applies tags for resource management.
// --------------------------------------------------------------------------------------

@description('Name of the DNS Zone')
param dnsZoneName string

@description('Name of the Traffic Manager profile')
param trafficManagerName string

@description('Name of the Front Door instance')
param frontDoorName string

@description('The resource ID of the central Log Analytics Workspace for global resource diagnostics.')
param globalLogAnalyticsWorkspaceId string

@description('Prefix for Function App names')
param functionAppNamePrefix string

@description('Prefix for Function App Storage accounts')
param functionStorageNamePrefix string

@description('Tags for resource management')
param tags object = {}

@description('Regions for Function Apps deployment')
param functionAppRegions array = [
  'eastus'
  'westeurope'
  // Add more regions as needed
]

@description('Name for the global control plane Cosmos DB account')
param globalControlCosmosDbName string

@description('Primary location for the global Cosmos DB')
param primaryLocation string

@description('Additional locations for geo-replication (array of objects with locationName, failoverPriority)')
param additionalLocations array

// DNS Zone
resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: dnsZoneName
  location: 'global'
  tags: tags
}

// Traffic Manager Profile
resource trafficManager 'Microsoft.Network/trafficManagerProfiles@2022-04-01' = {
  name: trafficManagerName
  location: 'global'
  tags: tags
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Performance'
    dnsConfig: {
      relativeName: dnsZoneName
      ttl: 60
    }
    monitorConfig: {
      protocol: 'HTTPS'
      port: 443
      path: '/health'
    }
  }
}

// Front Door Profile
resource frontDoor 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: frontDoorName
  location: 'global'
  sku: {
    name: 'Standard_Microsoft'
  }
  tags: tags
}

// Define Function Apps array
var functionApps = [for region in functionAppRegions: {
  name: '${functionAppNamePrefix}-${region}'
  storageName: '${functionStorageNamePrefix}${toLower(replace(region, ' ', ''))}'
  location: region
}]

// Storage Accounts for Function Apps
resource functionStorage 'Microsoft.Storage/storageAccounts@2022-09-01' = [for app in functionApps: {
  name: app.storageName
  location: app.location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {}
}]

// App Service Plans for Function Apps
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = [for app in functionApps: {
  name: '${app.name}-plan'
  location: app.location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}]

// Function Apps
resource functionApp 'Microsoft.Web/sites@2022-03-01' = [for (app, i) in functionApps: {
  name: app.name
  location: app.location
  kind: 'functionapp'
  properties: {
    serverFarmId: appServicePlan[i].id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorage[i].name};AccountKey=${listKeys(functionStorage[i].id, functionStorage[i].apiVersion).keys[0].value};EndpointSuffix=core.windows.net'
        }
        // Add additional settings here as needed
      ]
    }
    httpsOnly: true
  }
  identity: {
    type: 'SystemAssigned'
  }
  dependsOn: [
    functionStorage[i]
    appServicePlan[i]
  ]
}]

// Cosmos DB Account for global control plane
var additionalCosmosDbLocations = [for loc in additionalLocations: {
  locationName: loc.locationName
  failoverPriority: loc.failoverPriority
  isZoneRedundant: true
}]

var cosmosDbLocations = concat(
  [
    {
      locationName: primaryLocation
      failoverPriority: 0
      isZoneRedundant: true
    }
  ],
  additionalCosmosDbLocations
)

resource globalControlCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: globalControlCosmosDbName
  location: primaryLocation
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: cosmosDbLocations
    enableMultipleWriteLocations: true
    databaseAccountOfferType: 'Standard'
  }
}

// Diagnostics for Function Apps
resource functionAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (app, i) in functionApps: {
  name: '${app.name}-diagnostics'
  scope: functionApp[i]
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      {
        category: 'FunctionAppLogs'
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
}]

// Diagnostics for Storage Accounts
resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (app, i) in functionApps: {
  name: '${app.storageName}-diagnostics'
  scope: functionStorage[i]
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
}]

// Diagnostics for Cosmos DB
resource cosmosDbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'cosmosdb-diagnostics'
  scope: globalControlCosmosDb
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      {
        category: 'DataPlaneRequests'
        enabled: true
      }
      {
        category: 'MongoRequests'
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

// Diagnostics for Front Door
resource frontDoorDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'frontdoor-diagnostics'
  scope: frontDoor
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      {
        category: 'FrontdoorAccessLog'
        enabled: true
      }
      {
        category: 'FrontdoorWebApplicationFirewallLog'
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

// Diagnostics for Traffic Manager
resource trafficManagerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'trafficmanager-diagnostics'
  scope: trafficManager
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      {
        category: 'ProbeHealthStatus'
        enabled: true
      }
      {
        category: 'EndpointHealthStatus'
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

// Diagnostics for DNS Zone
resource dnsZoneDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'dnszone-diagnostics'
  scope: dnsZone
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      {
        category: 'DnsQueries'
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

// Outputs
output functionAppNames array = [for app in functionApps: app.name]
output message string = 'Global layer deployed successfully'
