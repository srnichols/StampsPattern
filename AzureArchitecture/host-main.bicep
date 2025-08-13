// Orchestrator for regional networking and CELL deployments in the Host subscription
// Consumes a central Log Analytics workspace resource ID from the Hub deployment

targetScope = 'resourceGroup'

@description('Tags to apply to all resources')
param tags object = {}

@description('Array of regions to deploy with regional prerequisites')
param regions array

@description('Cells to deploy across regions')
param cells array

@description('SQL admin username for per-cell SQL Servers')
param sqlAdminUsername string

@secure()
@description('SQL admin password for per-cell SQL Servers')
param sqlAdminPassword string

@description('The resource ID of the central Log Analytics Workspace')
param globalLogAnalyticsWorkspaceId string

@description('Treat as smoke? Disables some zone/HTTPS heavy bits when true')
param smoke bool = false

@description('Optional: force all regional backends to this single FQDN for demo/smoke (e.g., www.bing.com). When empty, use per-cell backend domains.')
param demoBackendFqdn string = ''

@description('Optional per-region override for the Key Vault SSL secret IDs (use to pass versioned SecretIds). Order must align with regions array.')
param sslCertSecretIdOverrides array = []

var isSmoke = smoke

// Helpers: region/geo short names and environment short code
var regionShortNames = {
  eastus: 'eus'
  eastus2: 'eus2'
  westus: 'wus'
  westus2: 'wus2'
  westus3: 'wus3'
  northeurope: 'neu'
  westeurope: 'weu'
}

var geoShortNames = {
  northamerica: 'us'
  europe: 'eu'
  asia: 'apac'
}

var envMap = {
  development: 'dev'
  dev: 'dev'
  test: 'tst'
  testing: 'tst'
  staging: 'stg'
  prod: 'prd'
  production: 'prd'
}

var environmentRaw = string(tags.?environment ?? 'dev')
var envShort = (envMap[?toLower(environmentRaw)] ?? substring(toLower(environmentRaw), 0, 3))


// Deterministic regional Key Vault names used for HTTPS certificates
var regionalKvNames = [
  for (region, idx) in regions: toLower('kv-${(geoShortNames[?region.geoName] ?? substring(region.geoName, 0, 2))}-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}-${substring(uniqueString(resourceGroup().id, region.regionName, 'agw-kv'), 0, 4)}')
]

// Regional network + monitoring
module regionalNetworks './regionalNetwork.bicep' = [for (region, idx) in regions: {
  name: 'regionalNetwork-${region.geoName}-${region.regionName}'
  params: {
    location: region.regionName
    geoName: region.geoName
    regionName: region.regionName
  vnetName: 'vnet-stamps-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}'
  subnetName: 'snet-agw-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}'
  publicIpName: 'pip-agw-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}'
  // Optional DNS label for quick demo access: agw-{regionShort}-{env}-{uu}
  publicIpDnsLabel: toLower('agw-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}-${substring(uniqueString(resourceGroup().id, region.regionName, 'pip'), 0, 4)}')
    tags: union(tags, { geo: region.geoName, region: region.regionName })
  }
}]

// Per-region User Assigned Managed Identity for Application Gateway to read Key Vault certs
resource uamis 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = [for (region, idx) in regions: {
  name: 'uami-agw-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}'
  location: region.regionName
  tags: union(tags, { geo: region.geoName, region: region.regionName })
}]

// Create or update the regional Key Vaults (to store SSL certs for App Gateway)
resource regionalKeyVaults 'Microsoft.KeyVault/vaults@2023-02-01' = [for (region, idx) in regions: {
  // kv-{geoShort}-{regionShort}-{envShort}-{uu}
  name: regionalKvNames[idx]
  location: region.regionName
  tags: union(tags, { geo: region.geoName, region: region.regionName })
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
  // Soft delete is always enabled by the service; omit properties
  // Note: Purge protection cannot be set to false explicitly. Omit to leave disabled by default.
  enableRbacAuthorization: false
    enabledForDeployment: false
    enabledForTemplateDeployment: false
    enabledForDiskEncryption: false
    publicNetworkAccess: 'Enabled'
  networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    // Start with no policies; grant UAMI access below via a separate accessPolicies resource
    accessPolicies: []
  }
}]


resource regionalKvPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2023-02-01' = [for (region, idx) in regions: {
  parent: regionalKeyVaults[idx]
  name: 'add'
  properties: {
    accessPolicies: [
      {
        objectId: uamis[idx].properties.principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: ['get', 'list']
        }
      }
    ]
  }
}]

// Create a self-signed certificate in each regional Key Vault for initial HTTPS bring-up
// Secret name: ssl-cert (AGW expects a Key Vault secret with the certificate content)

module monitoringLayers './monitoringLayer.bicep' = [for (region, idx) in regions: {
  name: 'monitoring-${region.geoName}-${region.regionName}'
  params: {
    location: region.regionName
  // law-{purpose}-{region-short}-{environment}
  logAnalyticsWorkspaceName: 'law-stamps-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}'
    retentionInDays: 30
    tags: union(tags, { geo: region.geoName, region: region.regionName })
  }
}]

module regionalLayers './regionalLayer.bicep' = [for (region, idx) in regions: {
  name: 'regional-${region.geoName}-${region.regionName}'
  params: {
    location: region.regionName
  appGatewayName: 'agw-${(geoShortNames[?region.geoName] ?? substring(region.geoName, 0, 2))}-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}'
    subnetId: regionalNetworks[idx].outputs.subnetId
    publicIpId: regionalNetworks[idx].outputs.publicIpId
  // Use versioned SecretId override if provided; otherwise build from vaultUri
  sslCertSecretId: (length(sslCertSecretIdOverrides) > idx && !empty(string(sslCertSecretIdOverrides[idx]))) ? sslCertSecretIdOverrides[idx] : uri(regionalKeyVaults[idx].properties.vaultUri, 'secrets/ssl-cert')
  cellCount: length(region.cells)
  // Default backend FQDNs per cell - point to function apps
  cellBackendFqdns: [for i in range(0, length(region.cells)): 'fa-stamps-${region.regionName}.azurewebsites.net']
  enableHttps: !isSmoke
  userAssignedIdentityId: uamis[idx].id
    tags: union(tags, { geo: region.geoName, region: region.regionName })
  // Use function app health endpoint for better monitoring
  healthProbePath: '/api/health'
  demoBackendFqdn: demoBackendFqdn
  automationAccountName: 'auto-${(geoShortNames[?region.geoName] ?? substring(region.geoName, 0, 2))}-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}'
  }
}]

module deploymentStampLayers './deploymentStampLayer.bicep' = [for (cell, idx) in cells: {
  name: 'cell-${cell.geoName}-${cell.regionName}-${cell.cellName}'
  params: {
    location: cell.regionName
  // Derive shorts and codes for names
  sqlServerName: toLower('sql-${(geoShortNames[?cell.geoName] ?? substring(cell.geoName, 0, 2))}-${(regionShortNames[?cell.regionName] ?? substring(cell.regionName, 0, 3))}-cell${(substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 2) == '00' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 2, 1) : (substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 1) == '0' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 1, 2) : substring(cell.cellName, length(cell.cellName) - 3, 3)))}-${envShort}')
    sqlAdminUsername: sqlAdminUsername
    sqlAdminPassword: sqlAdminPassword
    // Zone suffix for cell resources (z0/z2/z3)
  sqlDbName: toLower('sqldb-cell${(substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 2) == '00' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 2, 1) : (substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 1) == '0' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 1, 2) : substring(cell.cellName, length(cell.cellName) - 3, 3)))}-z${string(length(cell.availabilityZones))}-${(regionShortNames[?cell.regionName] ?? substring(cell.regionName, 0, 3))}-${envShort}')
    // Storage: st{geo}{region}{cNNN}z{z}{env}{uniq}
  storageAccountName: toLower('st${(geoShortNames[?cell.geoName] ?? substring(cell.geoName, 0, 2))}${(regionShortNames[?cell.regionName] ?? substring(cell.regionName, 0, 3))}cell${(substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 2) == '00' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 2, 1) : (substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 1) == '0' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 1, 2) : substring(cell.cellName, length(cell.cellName) - 3, 3)))}z${string(length(cell.availabilityZones))}${envShort}${substring(uniqueString(resourceGroup().id, cell.regionName, cell.cellName, deployment().name), 0, 2)}')
    // Key Vault: kv-{geo}-{region}-{cNNN}-{env}-{uu}
  keyVaultName: toLower('kv-${(geoShortNames[?cell.geoName] ?? substring(cell.geoName, 0, 2))}-${(regionShortNames[?cell.regionName] ?? substring(cell.regionName, 0, 3))}-cell${(substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 2) == '00' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 2, 1) : (substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 1) == '0' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 1, 2) : substring(cell.cellName, length(cell.cellName) - 3, 3)))}-${envShort}-${substring(uniqueString(resourceGroup().id, cell.regionName, cell.cellName), 0, 2)}')
    // Cosmos DB: cos{geo}{region}{cNNN}z{z}{env}{uniq}
  cosmosDbStampName: toLower('cosmos${(geoShortNames[?cell.geoName] ?? substring(cell.geoName, 0, 2))}${(regionShortNames[?cell.regionName] ?? substring(cell.regionName, 0, 3))}cell${(substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 2) == '00' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 2, 1) : (substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 1) == '0' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 1, 2) : substring(cell.cellName, length(cell.cellName) - 3, 3)))}z${string(length(cell.availabilityZones))}${envShort}${substring(uniqueString(resourceGroup().id, cell.regionName, cell.cellName, deployment().name), 0, 6)}')
    tags: union(tags, {
      geo: cell.geoName
      region: cell.regionName
      cell: cell.cellName
      availabilityZones: string(length(cell.availabilityZones))
      tenancyModel: toLower(cell.cellType)
      maxTenantCount: string(cell.maxTenantCount)
    })
  containerRegistryName: toLower('acr${(geoShortNames[?cell.geoName] ?? substring(cell.geoName, 0, 2))}${(regionShortNames[?cell.regionName] ?? substring(cell.regionName, 0, 3))}${envShort}')
    enableContainerRegistry: false
  containerAppName: toLower('ca-cell${(substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 2) == '00' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 2, 1) : (substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 1) == '0' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 1, 2) : substring(cell.cellName, length(cell.cellName) - 3, 3)))}-z${string(length(cell.availabilityZones))}-${(regionShortNames[?cell.regionName] ?? substring(cell.regionName, 0, 3))}-${envShort}')
    baseDomain: cell.baseDomain
    globalLogAnalyticsWorkspaceId: globalLogAnalyticsWorkspaceId
    cosmosAdditionalLocations: cell.?cosmosAdditionalLocations ?? []
    cosmosMultiWrite: bool(cell.?cosmosMultiWrite ?? false)
  // Disable Cosmos zone redundancy for test due to regional capacity constraints
  cosmosZoneRedundant: false
    // Choose storage SKU based on zone count: 0->RAGZRS, 2->GZRS, 3->Premium_ZRS
  storageSkuName: (length(cell.availabilityZones) >= 3
      ? 'Premium_ZRS'
      : (length(cell.availabilityZones) >= 2 ? 'Standard_GZRS' : 'Standard_RAGZRS'))
  createStorageAccount: true
    enableStorageObjectReplication: bool(cell.?enableStorageObjectReplication ?? false)
    storageReplicationDestinationId: string(cell.?storageReplicationDestinationId ?? '')
    enableSqlFailoverGroup: bool(cell.?enableSqlFailoverGroup ?? false)
    sqlSecondaryServerId: string(cell.?sqlSecondaryServerId ?? '')
    enableCellTrafficManager: false
    diagnosticsMode: isSmoke ? 'metricsOnly' : 'standard'
  }
  dependsOn: [regionalLayers, monitoringLayers]
}]

output lawId string = globalLogAnalyticsWorkspaceId
output regionalKeyVaultNames array = regionalKvNames
