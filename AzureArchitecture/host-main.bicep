
// Orchestrator for regional networking and CELL deployments in the Host subscription
// Consumes a central Log Analytics workspace resource ID from the Hub deployment

// 📚 Documentation:
// - Architecture Overview: ../docs/ARCHITECTURE_GUIDE.md
// - Deployment Guide: ../docs/DEPLOYMENT_ARCHITECTURE_GUIDE.md
// - Developer Quickstart: ../docs/DEVELOPER_QUICKSTART.md
//
// 📝 Notes for Developers:
// - This file is the main entry point for deploying all Host-side resources (regional and CELL layers).
// - Naming conventions for RGs, assets, and zones are enforced for consistency and automation. See docs for rationale.
// - The deployment expects a central Log Analytics Workspace (from the Hub) to be provisioned first.
// - You must provide valid values for all parameters in host-main.parameters.json before deployment.
// - For local development or testing, see the Developer Quickstart for emulator and tool setup.
//
// ⚠️ Prerequisites:
// - Ensure the Hub deployment is complete and the Log Analytics Workspace resource ID is available.
// - The StampsManagementClient app registration must exist in Entra ID; pass its IDs as parameters.
// - Review and update the regions/cells arrays to match your intended topology.
//
// For more, see the docs above or ask in the project discussions.

targetScope = 'subscription'



// Management Portal App Registration
@description('Application (client) ID for the StampsManagementClient enterprise app registration')
param managementClientAppId string
@description('Entra ID Tenant ID for the StampsManagementClient enterprise app registration')
param managementClientTenantId string

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

// Short names for Azure regions, used in resource naming for brevity and uniqueness.
var regionShortNames = {
  eastus: 'eus'
  eastus2: 'eus2'
  westus: 'wus'
  westus2: 'wus2'
  westus3: 'wus3'
  northeurope: 'neu'
  westeurope: 'weu'
}

// Short names for geographies, used in resource naming.
var geoShortNames = {
  northamerica: 'us'
  europe: 'eu'
  asia: 'apac'
}

// Maps environment names to short codes for resource naming.
var envMap = {
  development: 'dev'
  dev: 'dev'
  test: 'tst'
  testing: 'tst'
  staging: 'stg'
  prod: 'prd'
  production: 'prd'
}

// Derive the environment short code from tags or default to 'dev'.
var environmentRaw = string(tags.?environment ?? 'dev')
var envShort = (envMap[?toLower(environmentRaw)] ?? substring(toLower(environmentRaw), 0, 3))


// Create a resource group for global assets
// Note: The first region in the regions array is used for global RG location.
resource globalResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-stamps-global-${envShort}'
  location: regions[0].regionName
  tags: union(tags, { scope: 'global' })
}

// Create a resource group for each region
// Each region gets its own RG for isolation and quota management.
resource regionResourceGroups 'Microsoft.Resources/resourceGroups@2021-04-01' = [for region in regions: {
  name: 'rg-stamps-region-${region.geoName}-${region.regionName}-${envShort}'
  location: region.regionName
  tags: union(tags, { geo: region.geoName, region: region.regionName, scope: 'region' })
}]

// Create a resource group for each CELL
// CELLs are the core isolation boundary for tenants; each gets its own RG.
resource cellResourceGroups 'Microsoft.Resources/resourceGroups@2021-04-01' = [for cell in cells: {
  name: 'rg-stamps-cell-${cell.geoName}-${cell.regionName}-${cell.cellName}-${envShort}'
  location: cell.regionName
  tags: union(tags, {
    geo: cell.geoName
    region: cell.regionName
    cell: cell.cellName
    tenancyModel: toLower(cell.cellType)
    maxTenantCount: string(cell.maxTenantCount)
    scope: 'cell'
  })
}]

// Example: Deploy global assets into the global RG
// module globalAssets './globalLayer.bicep' = {
//   name: 'global-assets'
//   scope: resourceGroup('rg-global-${envShort}')
//   params: { ... }
// }

// Deploy regional modules into their region RGs
module regionalNetworks './regionalNetwork.bicep' = [for (region, idx) in regions: {
  name: 'regionalNetwork-${region.geoName}-${region.regionName}'
  scope: resourceGroup('rg-stamps-region-${region.geoName}-${region.regionName}-${envShort}')
  params: {
    location: region.regionName
    geoName: region.geoName
    regionName: region.regionName
    vnetName: 'vnet-stamps-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}'
    subnetName: 'snet-agw-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}'
    publicIpName: 'pip-agw-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}'
    publicIpDnsLabel: toLower('agw-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}-${substring(uniqueString(subscription().id, region.regionName, 'pip'), 0, 4)}')
    tags: union(tags, { geo: region.geoName, region: region.regionName })
  }
}]

// Deploy monitoring and regional layers into their region RGs
module monitoringLayers './monitoringLayer.bicep' = [for (region, idx) in regions: {
  name: 'monitoring-${region.geoName}-${region.regionName}'
  scope: resourceGroup('rg-region-${region.geoName}-${region.regionName}')
  params: {
    location: region.regionName
    logAnalyticsWorkspaceName: 'law-stamps-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}'
    retentionInDays: 30
    tags: union(tags, { geo: region.geoName, region: region.regionName })
  }
}]

module regionalLayers './regionalLayer.bicep' = [for (region, idx) in regions: {
  name: 'regional-${region.geoName}-${region.regionName}'
  scope: resourceGroup('rg-region-${region.geoName}-${region.regionName}')
  params: {
    location: region.regionName
    appGatewayName: 'agw-${(geoShortNames[?region.geoName] ?? substring(region.geoName, 0, 2))}-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}'
    subnetId: regionalNetworks[idx].outputs.subnetId
    publicIpId: regionalNetworks[idx].outputs.publicIpId
    sslCertSecretId: (length(sslCertSecretIdOverrides) > idx && !empty(string(sslCertSecretIdOverrides[idx]))) ? sslCertSecretIdOverrides[idx] : ''
    cellCount: length(region.cells)
    cellBackendFqdns: [for i in range(0, length(region.cells)): 'fa-stamps-${region.regionName}.azurewebsites.net']
    enableHttps: !isSmoke
    userAssignedIdentityId: ''
    tags: union(tags, { geo: region.geoName, region: region.regionName })
    healthProbePath: '/api/health'
    demoBackendFqdn: demoBackendFqdn
    automationAccountName: 'auto-${(geoShortNames[?region.geoName] ?? substring(region.geoName, 0, 2))}-${(regionShortNames[?region.regionName] ?? substring(region.regionName, 0, 3))}-${envShort}'
  }
}]

// Deploy the CELL module into each dedicated RG
module deploymentStampLayers './deploymentStampLayer.bicep' = [for (cell, idx) in cells: {
  name: 'cell-${cell.geoName}-${cell.regionName}-${cell.cellName}'
  scope: resourceGroup('rg-stamps-cell-${cell.geoName}-${cell.regionName}-${cell.cellName}-${envShort}')
  params: {
    location: cell.regionName
    sqlServerName: toLower('sql-${(geoShortNames[?cell.geoName] ?? substring(cell.geoName, 0, 2))}-${(regionShortNames[?cell.regionName] ?? substring(cell.regionName, 0, 3))}-cell${(substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 2) == '00' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 2, 1) : (substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 1) == '0' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 1, 2) : substring(cell.cellName, length(cell.cellName) - 3, 3)))}-${envShort}')
    sqlAdminUsername: sqlAdminUsername
    sqlAdminPassword: sqlAdminPassword
    sqlDbName: toLower('sqldb-cell${(substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 2) == '00' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 2, 1) : (substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 1) == '0' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 1, 2) : substring(cell.cellName, length(cell.cellName) - 3, 3)))}-z${string(length(cell.availabilityZones))}-${(regionShortNames[?cell.regionName] ?? substring(cell.regionName, 0, 3))}-${envShort}')
    storageAccountName: toLower('st${(geoShortNames[?cell.geoName] ?? substring(cell.geoName, 0, 2))}${(regionShortNames[?cell.regionName] ?? substring(cell.regionName, 0, 3))}cell${(substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 2) == '00' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 2, 1) : (substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 1) == '0' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 1, 2) : substring(cell.cellName, length(cell.cellName) - 3, 3)))}z${string(length(cell.availabilityZones))}${envShort}${substring(uniqueString(subscription().id, cell.regionName, cell.cellName, deployment().name), 0, 2)}')
    keyVaultName: toLower('kv-${(geoShortNames[?cell.geoName] ?? substring(cell.geoName, 0, 2))}-${(regionShortNames[?cell.regionName] ?? substring(cell.regionName, 0, 3))}-cell${(substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 2) == '00' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 2, 1) : (substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 1) == '0' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 1, 2) : substring(cell.cellName, length(cell.cellName) - 3, 3)))}-${envShort}-${substring(uniqueString(subscription().id, cell.regionName, cell.cellName), 0, 2)}')
    cosmosDbStampName: toLower('cosmos${(geoShortNames[?cell.geoName] ?? substring(cell.geoName, 0, 2))}${(regionShortNames[?cell.regionName] ?? substring(cell.regionName, 0, 3))}cell${(substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 2) == '00' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 2, 1) : (substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 0, 1) == '0' ? substring(substring(cell.cellName, length(cell.cellName) - 3, 3), 1, 2) : substring(cell.cellName, length(cell.cellName) - 3, 3)))}z${string(length(cell.availabilityZones))}${envShort}${substring(uniqueString(subscription().id, cell.regionName, cell.cellName, deployment().name), 0, 6)}')
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
    cosmosZoneRedundant: false
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
  dependsOn: [cellResourceGroups, regionalLayers, monitoringLayers]
}]

output lawId string = globalLogAnalyticsWorkspaceId
