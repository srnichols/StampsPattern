// Endpoints are now filtered in the deployment script. Use as-is.
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

@description('Additional locations for geo-replication (array of region names, e.g., ["westus2"])')
param additionalLocations array

@description('Whether Cosmos DB regions should be zone redundant (set false for lab/smoke in constrained regions)')
param cosmosZoneRedundant bool = true

@description('Enable deployment of global Function Apps and their plans/storage (disable in smoke/lab to avoid quota)')
param enableGlobalFunctions bool = true

@description('Enable deployment of the global control plane Cosmos DB (disable in smoke/lab to avoid regional capacity issues)')
param enableGlobalCosmos bool = true

@description('Array of regional endpoint FQDNs for Traffic Manager (e.g., Application Gateway FQDNs)')
param regionalEndpoints array = []



@description('APIM Gateway URL for Front Door origin configuration')
param apimGatewayUrl string = ''

@description('Azure Front Door SKU - Standard_AzureFrontDoor (minimum) or Premium_AzureFrontDoor (for Private Link)')
@allowed(['Standard_AzureFrontDoor', 'Premium_AzureFrontDoor'])
param frontDoorSku string = 'Standard_AzureFrontDoor'

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
      // Traffic Manager requires a single-label relative name, not a FQDN.
      // Derive a label from the dnsZoneName by taking the first label before the dot.
      relativeName: split(toLower(dnsZoneName), '.')[0]
      ttl: 60
    }
    monitorConfig: {
      protocol: 'HTTPS'
      port: 443
      path: '/health'
    }
    endpoints: regionalEndpoints
  }
}

// Modern Azure Front Door Profile (Standard/Premium)
resource frontDoor 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: frontDoorName
  location: 'global'
  sku: {
    name: frontDoorSku
  }
  tags: tags
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

// Front Door Endpoint
resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  name: 'stamps-global-endpoint'
  parent: frontDoor
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

// Origin Group for APIM Global Gateway (primary routing strategy)
resource apimOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = if (!empty(apimGatewayUrl)) {
  name: 'apim-global-origins'
  parent: frontDoor
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/status-0123456789abcdef'  // APIM default health endpoint
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
  }
}

// Origin for APIM Global Gateway
resource apimOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = if (!empty(apimGatewayUrl)) {
  name: 'apim-global-origin'
  parent: apimOriginGroup
  properties: {
    hostName: replace(apimGatewayUrl, 'https://', '')
    httpPort: 80
    httpsPort: 443
    originHostHeader: replace(apimGatewayUrl, 'https://', '')
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
}

// Primary Route to forward traffic to APIM (main traffic flow)
resource apimRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = if (!empty(apimGatewayUrl)) {
  name: 'apim-global-route'
  parent: frontDoorEndpoint
  properties: {
    customDomains: []
    originGroup: {
      id: apimOriginGroup.id
    }
    originPath: null
    ruleSets: []
    supportedProtocols: ['Http', 'Https']
    patternsToMatch: ['/*']
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
  dependsOn: [
    apimOrigin
  ]
}


// Fallback routing for regional Application Gateways must be implemented manually if needed.

@description('Enable diagnostic settings for Front Door (some categories may be restricted by SKU/region).')
param enableFrontDoorDiagnostics bool = false

@description('Enable diagnostic settings for Traffic Manager (categories vary; disabled in smoke).')
param enableTrafficManagerDiagnostics bool = false

// Define Function Apps array
var functionApps = [for region in functionAppRegions: {
  name: '${functionAppNamePrefix}-${region}'
  storageName: '${functionStorageNamePrefix}${toLower(replace(region, ' ', ''))}'
  location: region
}]

// Effective arrays based on toggle
var functionAppsEff = enableGlobalFunctions ? functionApps : []

// Storage Accounts for Function Apps
resource functionStorage 'Microsoft.Storage/storageAccounts@2022-09-01' = [for app in functionAppsEff: {
  name: app.storageName
  location: app.location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {}
}]

// Consumption (Dynamic) plans for Azure Functions (not Web Apps)
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = [for app in functionAppsEff: {
  name: '${app.name}-plan'
  location: app.location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}]

// Function Apps
resource functionApp 'Microsoft.Web/sites@2022-03-01' = [for (app, i) in functionAppsEff: {
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
var additionalCosmosDbLocations = [for (loc, idx) in additionalLocations: {
  locationName: string(loc)
  failoverPriority: idx + 1
  isZoneRedundant: cosmosZoneRedundant
}]

var cosmosDbLocations = concat(
  [
    {
      locationName: primaryLocation
      failoverPriority: 0
  isZoneRedundant: cosmosZoneRedundant
    }
  ],
  additionalCosmosDbLocations
)

resource globalControlCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = if (enableGlobalCosmos) {
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
resource functionAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (app, i) in functionAppsEff: {
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
resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (app, i) in functionAppsEff: {
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
resource cosmosDbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableGlobalCosmos) {
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
resource frontDoorDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableFrontDoorDiagnostics) {
  name: 'frontdoor-diagnostics'
  scope: frontDoor
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    // Use categories commonly available; AccessLog may not be supported on all SKUs
    logs: [
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
resource trafficManagerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableTrafficManagerDiagnostics) {
  name: 'trafficmanager-diagnostics'
  scope: trafficManager
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      // Category availability varies; start with EndpointHealthStatus only
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
// Note: Microsoft.Network/dnsZones does not support diagnostic settings; removing unsupported diagnostics.

// Outputs
output functionAppNames array = [for app in functionApps: app.name]
output message string = 'Global layer deployed successfully'
output trafficManagerFqdn string = trafficManager.properties.dnsConfig.fqdn
output frontDoorProfileName string = frontDoor.name
output frontDoorEndpointHostname string = frontDoorEndpoint.properties.hostName
output dnsZoneName string = dnsZone.name
