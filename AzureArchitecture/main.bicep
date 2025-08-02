// Azure Stamps Pattern - Main Orchestration Template
// This file works with the existing module parameter schemas

targetScope = 'resourceGroup'

// ============ PARAMETERS ============
// Organization Parameters
@description('The organization domain (e.g., contoso.com)')
param organizationDomain string = 'contoso.com'

@description('The organization name for resource naming')
param organizationName string = 'contoso'

@description('The department responsible for the deployment')
param department string = 'IT'

@description('The project name for resource tagging and naming')
param projectName string = 'StampsPattern'

@description('The workload name for resource tagging')
param workloadName string = 'stamps-pattern'

@description('The owner email for resource tagging')
param ownerEmail string = 'platform-team@contoso.com'

// Geography Parameters
@description('The geography name (e.g., northamerica, europe, asia)')
param geoName string = 'northamerica'

@description('The base DNS zone name (without domain)')
param baseDnsZoneName string = 'stamps'

// Deployment Parameters
@description('Environment name for deployment')
@allowed(['dev', 'test', 'staging', 'prod'])
param environment string = 'dev'

@description('Name of the DNS Zone')
param dnsZoneName string = '${baseDnsZoneName}.${organizationDomain}'

@description('Name of the Traffic Manager profile')
param trafficManagerName string = 'tm-stamps-global'

@description('Name of the Front Door instance')
param frontDoorName string = 'fd-stamps-global'

@description('Prefix for Function App names')
param functionAppNamePrefix string = 'fa-stamps'

@description('Prefix for Function App Storage accounts')
param functionStorageNamePrefix string = 'stfastamps'

@description('Name for the global control Cosmos DB')
param globalControlCosmosDbName string = 'cosmos-stamps-control'

@description('Primary location for global resources')
param primaryLocation string = 'eastus'

@description('Additional locations for replication')
param additionalLocations array = ['westus2']

@description('Regions for Function Apps deployment')
param functionAppRegions array = ['eastus', 'westus2']

@secure()
@description('Administrator username for SQL Server')
param sqlAdminUsername string

@secure()
@description('Administrator password for SQL Server')
param sqlAdminPassword string

@description('Array of regions to deploy stamps to')
param regions array = [
  {
    geoName: geoName
    regionName: 'eastus'
    cells: ['cell1', 'cell2']
    baseDomain: 'eastus.${baseDnsZoneName}.${organizationDomain}'
    keyVaultName: 'kv-stamps-na-eus'
    logAnalyticsWorkspaceName: 'law-stamps-na-eus'
  }
  {
    geoName: geoName
    regionName: 'westus2'
    cells: ['cell1', 'cell2']
    baseDomain: 'westus2.${baseDnsZoneName}.${organizationDomain}'
    keyVaultName: 'kv-stamps-na-wus2'
    logAnalyticsWorkspaceName: 'law-stamps-na-wus2'
  }
]

@description('Array of cells (deployment stamps) to deploy')
param cells array = [
  {
    geoName: geoName
    regionName: 'eastus'
    cellName: 'shared-smb-z2'
    cellType: 'Shared'
    availabilityZones: ['1', '2']
    maxTenantCount: 100
    baseDomain: 'eastus.${baseDnsZoneName}.${organizationDomain}'
    keyVaultName: 'kv-stamps-na-eus'
    logAnalyticsWorkspaceName: 'law-stamps-na-eus'
  }
  {
    geoName: geoName
    regionName: 'eastus'
    cellName: 'dedicated-enterprise-z3'
    cellType: 'Dedicated'
    availabilityZones: ['1', '2', '3']
    maxTenantCount: 1
    baseDomain: 'eastus.${baseDnsZoneName}.${organizationDomain}'
    keyVaultName: 'kv-stamps-na-eus'
    logAnalyticsWorkspaceName: 'law-stamps-na-eus'
  }
  {
    geoName: geoName
    regionName: 'westus2'
    cellName: 'shared-startup-z2'
    cellType: 'Shared'
    availabilityZones: ['1', '2']
    maxTenantCount: 50
    baseDomain: 'westus2.${baseDnsZoneName}.${organizationDomain}'
    keyVaultName: 'kv-stamps-na-wus2'
    logAnalyticsWorkspaceName: 'law-stamps-na-wus2'
  }
  {
    geoName: geoName
    regionName: 'westus2'
    cellName: 'dedicated-healthcare-z3'
    cellType: 'Dedicated'
    availabilityZones: ['1', '2', '3']
    maxTenantCount: 1
    baseDomain: 'westus2.${baseDnsZoneName}.${organizationDomain}'
    keyVaultName: 'kv-stamps-na-wus2'
    logAnalyticsWorkspaceName: 'law-stamps-na-wus2'
  }
]

// ============ VARIABLES ============
var baseTags = {
  environment: environment
  department: department
  project: projectName
  deployedBy: 'Bicep'
  workload: workloadName
  owner: ownerEmail
}

// ============ GLOBAL LAYER ============
module globalLayer './globalLayer.bicep' = {
  name: 'globalLayer'
  params: {
    dnsZoneName: dnsZoneName
    trafficManagerName: trafficManagerName
    frontDoorName: frontDoorName
    globalLogAnalyticsWorkspaceId: '' // Will be updated after workspace creation
    functionAppNamePrefix: functionAppNamePrefix
    functionStorageNamePrefix: functionStorageNamePrefix
    tags: baseTags
    functionAppRegions: functionAppRegions
    globalControlCosmosDbName: globalControlCosmosDbName
    primaryLocation: primaryLocation
    additionalLocations: additionalLocations
  }
}

// ============ KEY VAULTS ============
module keyVaults './keyvault.bicep' = [
  for (region, index) in regions: {
    name: 'keyVault-${region.geoName}-${region.regionName}'
    params: {
      name: region.keyVaultName
      location: region.regionName
      skuName: 'standard'
      tags: union(baseTags, {
        geo: region.geoName
        region: region.regionName
      })
    }
  }
]

// ============ REGIONAL LAYER ============
module regionalLayers './regionalLayer.bicep' = [
  for (region, index) in regions: {
    name: 'regionalLayer-${region.geoName}-${region.regionName}'
    params: {
      location: region.regionName
      appGatewayName: 'agw-${region.geoName}-${region.regionName}'
      subnetId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/virtualNetworks/vnet-${region.geoName}-${region.regionName}/subnets/subnet-agw'
      publicIpId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/publicIPAddresses/pip-agw-${region.geoName}-${region.regionName}'
      sslCertSecretId: 'https://${region.keyVaultName}.${az.environment().suffixes.keyvaultDns}/secrets/ssl-cert'
      cellCount: length(region.cells)
      cellBackendFqdns: [for cell in region.cells: '${cell}.backend.${region.baseDomain}']
      tags: union(baseTags, {
        geo: region.geoName
        region: region.regionName
      })
      healthProbePath: '/health'
      automationAccountName: 'auto-${region.geoName}-${region.regionName}'
      automationAccountSkuName: 'Basic'
    }
    dependsOn: [
      keyVaults
    ]
  }
]

// ============ MONITORING LAYER ============
module monitoringLayers './monitoringLayer.bicep' = [
  for (region, index) in regions: {
    name: 'monitoringLayer-${region.geoName}-${region.regionName}'
    params: {
      location: region.regionName
      logAnalyticsWorkspaceName: region.logAnalyticsWorkspaceName
      retentionInDays: 30
      tags: union(baseTags, {
        geo: region.geoName
        region: region.regionName
      })
    }
  }
]

// ============ DEPLOYMENT STAMP LAYER (CELLS) ============
module deploymentStampLayers './deploymentStampLayer.bicep' = [
  for (cell, index) in cells: {
    name: 'deploymentStampLayer-${cell.geoName}-${cell.regionName}-${cell.cellName}'
    params: {
      location: cell.regionName
      sqlServerName: 'sql-${cell.geoName}-${cell.regionName}-${cell.cellName}'
      sqlAdminUsername: sqlAdminUsername
      sqlAdminPassword: sqlAdminPassword
      sqlDbName: 'sqldb-${cell.geoName}-${cell.regionName}-${cell.cellName}'
      storageAccountName: 'st${cell.geoName}${cell.regionName}${cell.cellName}'
      keyVaultName: 'kv-${cell.geoName}-${cell.regionName}-${cell.cellName}'
      cosmosDbStampName: 'cosmos-${cell.geoName}-${cell.regionName}-${cell.cellName}'
      tags: union(baseTags, {
        geo: cell.geoName
        region: cell.regionName
        cell: cell.cellName
        availabilityZones: string(length(cell.availabilityZones))  // Convert zone count to string
        tenancyModel: toLower(cell.cellType)   // 'Shared' -> 'shared', 'Dedicated' -> 'dedicated'
        maxTenantCount: string(cell.maxTenantCount)
        workload: 'stamps-pattern'
        costCenter: 'IT-Infrastructure'
      })
      zones: cell.availabilityZones
      containerRegistryName: 'acr${cell.geoName}${cell.regionName}${cell.cellName}'
      containerAppName: cell.cellName
      baseDomain: cell.baseDomain
      globalLogAnalyticsWorkspaceId: monitoringLayers[0].outputs.logAnalyticsWorkspaceId
    }
    dependsOn: [
      regionalLayers
      monitoringLayers
    ]
  }
]

// ============ OUTPUTS ============
output globalLayerOutputs object = globalLayer.outputs

output keyVaultOutputs array = [
  for (region, index) in regions: {
    geoName: region.geoName
    regionName: region.regionName
    keyVaultId: keyVaults[index].outputs.id
    keyVaultName: keyVaults[index].outputs.vaultName
  }
]

output regionalLayerOutputs array = [
  for (region, index) in regions: {
    geoName: region.geoName
    regionName: region.regionName
    automationAccountId: regionalLayers[index].outputs.automationAccountId
    publicIpAddress: regionalLayers[index].outputs.regionalEndpointIpAddress
  }
]

output deploymentStampOutputs array = [
  for (cell, index) in cells: {
    geoName: cell.geoName
    regionName: cell.regionName
    cellName: cell.cellName
    acrLoginServer: deploymentStampLayers[index].outputs.acrLoginServer
    acrId: deploymentStampLayers[index].outputs.acrId
    acrSystemAssignedPrincipalId: deploymentStampLayers[index].outputs.acrSystemAssignedPrincipalId
    keyVaultId: deploymentStampLayers[index].outputs.keyVaultId
    keyVaultUri: deploymentStampLayers[index].outputs.keyVaultUri
    sqlServerSystemAssignedPrincipalId: deploymentStampLayers[index].outputs.sqlServerSystemAssignedPrincipalId
    storageAccountSystemAssignedPrincipalId: deploymentStampLayers[index].outputs.storageAccountSystemAssignedPrincipalId
  }
]
