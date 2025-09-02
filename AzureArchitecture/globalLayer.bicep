// Store global Cosmos DB connection string in Key Vault using a deploymentScript
resource storeGlobalCosmosDbConnectionScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (enableGlobalCosmos) {
  name: 'store-global-cosmosdb-connection-script'
  location: primaryLocation
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.53.0'
    timeout: 'PT10M'
    cleanupPreference: 'OnSuccess'
    forceUpdateTag: uniqueString(globalControlCosmosDbName, keyVaultName)
    environmentVariables: [
      {
        name: 'COSMOS_DB_ACCOUNT'
        value: globalControlCosmosDb.name
      }
      {
        name: 'COSMOS_DB_RG'
        value: resourceGroup().name
      }
      {
        name: 'KEYVAULT_NAME'
        value: keyVaultName
      }
      {
        name: 'SECRET_NAME'
        value: 'CosmosDbConnection'
      }
    ]
    scriptContent: '''
      set -e
      connstr=$(az cosmosdb keys list --name "$COSMOS_DB_ACCOUNT" --resource-group "$COSMOS_DB_RG" --type connection-strings --query "connectionStrings[0].connectionString" -o tsv)
      az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "$SECRET_NAME" --value "$connstr"
    '''
    retentionInterval: 'P1D'
  }
  // dependsOn removed as per linter suggestion
}
// ...existing code...
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

// The globalLogAnalyticsWorkspaceId parameter is required for diagnostics on global resources (Function Apps, Storage, Cosmos DB, Front Door, Traffic Manager, etc.).
// This value is passed from main.bicep, which gets it from monitoringLayers[0].outputs.logAnalyticsWorkspaceId.
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

@description('Name of the Key Vault to use for global secrets')
param keyVaultName string

@description('Primary location for the global Cosmos DB')
param primaryLocation string

@description('Additional locations for geo-replication (array of region names, e.g., ["westus2"])')
param additionalLocations array

@description('Enable zone redundancy for Cosmos DB regions in this module (true = zone redundant). Recommended: true in prod, false otherwise.')
param cosmosZoneRedundant bool = false

@description('Enable deployment of global Function Apps and their plans/storage (disable in smoke/lab to avoid quota)')
param enableGlobalFunctions bool = true

@description('Enable deployment of the global control plane Cosmos DB (disable in smoke/lab to avoid regional capacity issues)')
param enableGlobalCosmos bool = true

@description('Array of regional endpoint FQDNs for Traffic Manager (e.g., Application Gateway FQDNs)')
param regionalEndpoints array = []



@description('APIM Gateway URL for Front Door origin configuration (legacy single)')
param apimGatewayUrl string = ''

@description('APIM Gateway URLs for Front Door origin configuration (primary + secondaries)')
param apimGatewayUrls array = []

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
// Create an origin group if we have at least one APIM gateway URL
resource apimOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = if (!empty(apimGatewayUrls) || !empty(apimGatewayUrl)) {
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
// Create one origin per APIM gateway URL
resource apimOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = [for (url, i) in (length(apimGatewayUrls) > 0 ? apimGatewayUrls : [apimGatewayUrl]): if (!empty(url)) {
  name: length(apimGatewayUrls) > 0 ? 'apim-origin-${i}' : 'apim-global-origin'
  parent: apimOriginGroup
  properties: {
    hostName: replace(url, 'https://', '')
    httpPort: 80
    httpsPort: 443
    originHostHeader: replace(url, 'https://', '')
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
}]

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
  // LOG_ANALYTICS_WORKSPACE_KEY setting removed; add back with correct Key Vault reference if needed
        {
          name: 'CosmosDbConnection'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/CosmosDbConnection)'
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
