// Azure Stamps Pattern - Main Orchestration Template
targetScope = 'resourceGroup'

@description('Global prefix for resource naming')
param globalPrefix string = 'stamps'

@description('Environment type')
@allowed(['dev', 'test', 'prod'])
param environmentType string = 'dev'

@secure()
@description('Administrator username for SQL Server')
param sqlAdminUsername string

@secure()
@description('Administrator password for SQL Server')
param sqlAdminPassword string

@description('Log retention in days')
param logRetentionInDays int = 30

@description('Array of regions to deploy to')
param regions array = [
  {
    geoName: 'northamerica'
    regionName: 'eastus'
    cells: ['cell1', 'cell2']
    baseDomain: 'eastus.contoso.com'
    keyVaultName: 'kv-northamerica-eastus'
    logAnalyticsWorkspaceName: 'law-northamerica-eastus'
  }
]

@description('Array of cells to deploy')
param cells array = [
  {
    geoName: 'northamerica'
    regionName: 'eastus'
    cellName: 'cell1'
    baseDomain: 'eastus.contoso.com'
    keyVaultName: 'kv-northamerica-eastus'
    logAnalyticsWorkspaceName: 'law-northamerica-eastus'
  }
  {
    geoName: 'northamerica'
    regionName: 'eastus'
    cellName: 'cell2'
    baseDomain: 'eastus.contoso.com'
    keyVaultName: 'kv-northamerica-eastus'
    logAnalyticsWorkspaceName: 'law-northamerica-eastus'
  }
]

var baseTags = {
  environment: environmentType
  project: 'StampsPattern'
  deployedBy: 'Bicep'
  deploymentDate: utcNow('yyyy-MM-dd')
}

module globalLayer './globalLayer.bicep' = {
  name: 'globalLayer'
  params: {
    globalPrefix: globalPrefix
    environmentType: environmentType
    logRetentionInDays: logRetentionInDays
    tags: baseTags
  }
}

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
      globalLogAnalyticsWorkspaceId: globalLayer.outputs.logAnalyticsWorkspaceId
    }
  }
]

module regionalLayers './regionalLayer.bicep' = [
  for (region, index) in regions: {
    name: 'regionalLayer-${region.geoName}-${region.regionName}'
    params: {
      location: region.regionName
      appGatewayName: 'agw-${region.geoName}-${region.regionName}'
      subnetId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/virtualNetworks/vnet-${region.geoName}-${region.regionName}/subnets/subnet-agw'
      publicIpId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/publicIPAddresses/pip-agw-${region.geoName}-${region.regionName}'
      sslCertSecretId: 'https://${region.keyVaultName}.${environment().suffixes.keyvaultDns}/secrets/ssl-cert'
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

module monitoringLayers './monitoringLayer.bicep' = [
  for (region, index) in regions: {
    name: 'monitoringLayer-${region.geoName}-${region.regionName}'
    params: {
      location: region.regionName
      logAnalyticsWorkspaceName: region.logAnalyticsWorkspaceName
      applicationInsightsName: 'appi-${region.geoName}-${region.regionName}'
      tags: union(baseTags, {
        geo: region.geoName
        region: region.regionName
      })
    }
  }
]

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
      cosmosDbStampName: 'cosmos-${cell.geoName}-${cell.regionName}-${cell.cellName}'
      tags: union(baseTags, {
        geo: cell.geoName
        region: cell.regionName
        cell: cell.cellName
      })
      zones: ['1', '2']
      containerRegistryName: 'acr${cell.geoName}${cell.regionName}${cell.cellName}'
      containerAppName: cell.cellName
      baseDomain: cell.baseDomain
      globalLogAnalyticsWorkspaceId: globalLayer.outputs.logAnalyticsWorkspaceId
    }
    dependsOn: [
      regionalLayers
      monitoringLayers
    ]
  }
]

output globalLayerOutputs object = globalLayer.outputs

output keyVaultOutputs array = [
  for (region, index) in regions: {
    geoName: region.geoName
    regionName: region.regionName
    keyVaultId: keyVaults[index].outputs.id
    keyVaultUri: keyVaults[index].outputs.uri
  }
]

output regionalLayerOutputs array = [
  for (region, index) in regions: {
    geoName: region.geoName
    regionName: region.regionName
    applicationGatewayId: regionalLayers[index].outputs.applicationGatewayId
    publicIpAddress: regionalLayers[index].outputs.publicIpAddress
  }
]

output deploymentStampOutputs array = [
  for (cell, index) in cells: {
    geoName: cell.geoName
    regionName: cell.regionName
    cellName: cell.cellName
    sqlServerFqdn: deploymentStampLayers[index].outputs.sqlServerFqdn
    storageAccountName: deploymentStampLayers[index].outputs.storageAccountName
    cosmosDbEndpoint: deploymentStampLayers[index].outputs.cosmosDbEndpoint
  }
]
