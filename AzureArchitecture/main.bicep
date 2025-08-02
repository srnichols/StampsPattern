// --------------------------------------------------------------------------------------
// Azure CELL Architecture: Main Orchestration Template
// - Global Control Plane: DNS, Traffic Manager, Front Door, Log Analytics
// - Regional Layer: Networking, Key Vault, Monitoring
// - CELL Layer: Isolated app/data resources per region
// - Explicit GEO grouping for clarity
// - Explicit dependsOn for cross-layer dependencies
// --------------------------------------------------------------------------------------

targetScope = 'resourceGroup'

// Parameters for global resources
@description('Name of the DNS Zone')
param dnsZoneName string

@description('Name of the Traffic Manager profile')
param trafficManagerName string

@description('Name of the Front Door instance')
param frontDoorName string

@description('Location for the central Log Analytics Workspace')
param globalLogAnalyticsLocation string

@description('Name for the central Log Analytics Workspace')
param globalLogAnalyticsWorkspaceName string

@description('SQL admin username')
param sqlAdminUsername string

@secure()
@description('SQL admin password')
param sqlAdminPassword string

@description('Prefix for Function App names')
param functionAppNamePrefix string

@description('Prefix for Function App Storage accounts')
param functionStorageNamePrefix string

@description('Array of region objects for multi-region deployment')
param geos array

@description('Name for the APIM instance')
param apimName string

@description('Publisher email for APIM')
param apimPublisherEmail string

@description('Publisher name for APIM')
param apimPublisherName string

@description('Name for the global control plane Cosmos DB account')
param globalControlCosmosDbName string

@description('Primary location for the global Cosmos DB')
param primaryLocation string

@description('Additional locations for geo-replication (array of objects with locationName, failoverPriority)')
param additionalLocations array

// Base tags variable for DRY code
var baseTags = {
  environment: 'demo'
  department: 'IT'
}

// Global Log Analytics Workspace
resource globalLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: globalLogAnalyticsWorkspaceName
  location: globalLogAnalyticsLocation
  properties: {
    retentionInDays: 30
  }
}

// Global Layer deployment
module globalLayer './globalLayer.bicep' = {
  name: 'globalLayer'
  params: {
    dnsZoneName: dnsZoneName
    trafficManagerName: trafficManagerName
    frontDoorName: frontDoorName
    globalLogAnalyticsWorkspaceId: globalLogAnalyticsWorkspace.id
    functionAppNamePrefix: functionAppNamePrefix
    functionStorageNamePrefix: functionStorageNamePrefix
    globalControlCosmosDbName: globalControlCosmosDbName
    primaryLocation: primaryLocation
    additionalLocations: additionalLocations
    tags: baseTags
  }
}

// Geodes Layer deployment (APIM + Global Cosmos DB)
module geodesLayer './geodesLayer.bicep' = {
  name: 'geodesLayer'
  params: {
    location: primaryLocation
    apimName: apimName
    apimPublisherEmail: apimPublisherEmail
    apimPublisherName: apimPublisherName
    globalControlCosmosDbName: globalControlCosmosDbName
    primaryLocation: primaryLocation
    additionalLocations: additionalLocations
    tags: baseTags
  }
}

// Regional deployments
module regionalLayers './regionalLayer.bicep' = [
  for (geo, geoIdx) in geos
  for (region, regionIdx) in geo.regions: {
    name: 'regionalLayer-${geo.geoName}-${region.regionName}'
    params: {
      location: region.regionName
      appGatewayName: 'agw-${geo.geoName}-${region.regionName}'
      subnetId: '...' // supply as needed
      publicIpId: '...' // supply as needed
      sslCertSecretId: '...' // supply as needed
      cellCount: length(region.cells)
      cellBackendFqdns: [for cell in region.cells: '${cell}.backend.${region.regionName}.contoso.com']
      tags: union(baseTags, {
        geo: geo.geoName
        region: region.regionName
      })
      healthProbePath: '/health'
      automationAccountName: 'auto-${geo.geoName}-${region.regionName}'
      automationAccountSkuName: 'Basic'
    }
  }
]

// Monitoring Layer deployments
module monitoringLayers './monitoringLayer.bicep' = [
  for (geo, geoIdx) in geos
  for (region, regionIdx) in geo.regions: {
    name: 'monitoringLayer-${geo.geoName}-${region.regionName}'
    params: {
      location: region.regionName
      logAnalyticsWorkspaceName: region.logAnalyticsWorkspaceName
      retentionInDays: 30
      tags: union(baseTags, {
        geo: geo.geoName
        region: region.regionName
      })
    }
  }
]

// CELL/Stamp Layer deployments
module deploymentStampLayers './deploymentStampLayer.bicep' = [
  for (geo, geoIdx) in geos
  for (region, regionIdx) in geo.regions
  for (cell, cellIdx) in region.cells: {
    name: 'deploymentStampLayer-${geo.geoName}-${region.regionName}-${cell}'
    params: {
      location: region.regionName
      sqlServerName: 'sql-${geo.geoName}-${region.regionName}-${cell}'
      sqlAdminUsername: sqlAdminUsername
      sqlAdminPassword: sqlAdminPassword
      sqlDbName: 'sqldb-${geo.geoName}-${region.regionName}-${cell}'
      storageAccountName: 'st${geo.geoName}${region.regionName}${cell}'
      cosmosDbStampName: 'cosmos-${geo.geoName}-${region.regionName}-${cell}'
      tags: union(baseTags, {
        geo: geo.geoName
        region: region.regionName
        cell: cell
      })
      zones: ['1', '2']
      containerRegistryName: 'acr${geo.geoName}${region.regionName}${cell}'
      containerAppName: cell
      baseDomain: region.baseDomain
      globalLogAnalyticsWorkspaceId: globalLogAnalyticsWorkspace.id
    }
  }
]

// Key Vaults deployment - Using direct resource definitions
module keyVaults './keyvault.bicep' = [
  for (geo, geoIdx) in geos
  for (region, regionIdx) in geo.regions: {
    name: 'keyVault-${geo.geoName}-${region.regionName}'
    params: {
      name: region.keyVaultName
      location: region.regionName
      skuName: 'standard'
      tags: union(baseTags, {
        geo: geo.geoName
        region: region.regionName
      })
      globalLogAnalyticsWorkspaceId: globalLogAnalyticsWorkspace.id
    }
  }
]
