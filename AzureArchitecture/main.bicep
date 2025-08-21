// Azure Stamps Pattern - Main Orchestration Template
// This file works with the existing module parameter schemas

targetScope = 'subscription'
// Create a resource group for global assets
resource globalResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-global-${environment}'
  location: primaryLocation
  tags: union(baseTags, { scope: 'global' })
}

// Create a resource group for each region
resource regionResourceGroups 'Microsoft.Resources/resourceGroups@2021-04-01' = [for region in regions: {
  name: 'rg-region-${region.geoName}-${region.regionName}'
  location: region.regionName
  tags: union(baseTags, { geo: region.geoName, region: region.regionName, scope: 'region' })
}]

// Create a resource group for each CELL
resource cellResourceGroups 'Microsoft.Resources/resourceGroups@2021-04-01' = [for cell in cells: {
  name: 'rg-cell-${cell.geoName}-${cell.regionName}-${cell.cellName}'
  location: cell.regionName
  tags: union(baseTags, {
    geo: cell.geoName
    region: cell.regionName
    cell: cell.cellName
    tenancyModel: toLower(cell.cellType)
    maxTenantCount: string(cell.maxTenantCount)
    scope: 'cell'
  })
}]

// ============ PARAMETERS ============
// Organization Parameters
@description('The organization domain (e.g., contoso.com)')
param organizationDomain string = 'contoso.com'

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

@description('High-level environment profile to drive safe defaults (smoke/dev/prod). Smoke keeps footprint minimal and disables optional features; dev/prod enable full features.')
@allowed(['smoke','dev','prod'])
param environmentProfile string = 'dev'

@description('Minimum number of availability zones required')
@minValue(1)
@maxValue(3)
param minAvailabilityZones int = 2

@description('Maximum tenants allowed per shared CELL')
@minValue(10)
@maxValue(1000)
param maxTenantsPerSharedCell int = 100

@description('Name of the DNS Zone')
param dnsZoneName string = '${baseDnsZoneName}.${organizationDomain}'

@description('Name of the Traffic Manager profile')
param trafficManagerName string = 'tm-stamps-global'

@description('Name of the Front Door instance')
param frontDoorName string = 'fd-stamps-global'

@description('Azure Front Door SKU - Standard_AzureFrontDoor (minimum) or Premium_AzureFrontDoor (for Private Link)')
@allowed(['Standard_AzureFrontDoor', 'Premium_AzureFrontDoor'])
param frontDoorSku string = 'Standard_AzureFrontDoor'

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
@minLength(1)
@maxLength(10)
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
@minLength(1)
@maxLength(50)
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

@description('Use HTTP for Application Gateway listeners in lab/smoke (no Key Vault cert required)')
param useHttpForSmoke bool = true

// Derived flag: treat either explicit useHttpForSmoke or environmentProfile==smoke as smoke mode
var isSmoke = useHttpForSmoke || environmentProfile == 'smoke'

// ============ OPTIONAL DATA HA/DR KNOBS (safe defaults) ============
// Note: These knobs apply to CELL-layer resources only. Global control plane replication
// is configured in globalLayer and is not tenant/team configurable.
@description('Additional Cosmos DB locations to add to each CELL (optional)')
param cosmosAdditionalLocations array = []

@description('Enable multi-write for Cosmos DB across locations (A/A)')
param cosmosMultiWrite bool = false

@allowed([ 'Premium_ZRS', 'Standard_GZRS', 'Standard_RAGZRS' ])
@description('Default storage SKU for CELL storage accounts')
param storageSkuName string = 'Premium_ZRS'

@description('Enable Blob Object Replication (ORS) from each CELL to a destination account')
param enableStorageObjectReplication bool = false

@description('Enable SQL Auto-failover Group for each CELL')
param enableSqlFailoverGroup bool = false

// ============ VARIABLES ============
var baseTags = {
  environment: environment
  department: department
  project: projectName
  deployedBy: 'Bicep'
  workload: workloadName
  owner: ownerEmail
}

// Validation: Ensure all cells meet minimum availability zone requirements
var cellValidation = [for cell in cells: {
  isValid: length(cell.availabilityZones) >= minAvailabilityZones
  cellName: cell.cellName
  zoneCount: length(cell.availabilityZones)
}]

// Validation: Ensure shared cells don't exceed max tenant limit
var tenantValidation = [for cell in cells: {
  isValid: cell.cellType == 'Dedicated' || cell.maxTenantCount <= maxTenantsPerSharedCell
  cellName: cell.cellName
  tenantCount: cell.maxTenantCount
}]

// ============ GLOBAL LAYER ============
module globalLayer './globalLayer.bicep' = {
  name: 'globalLayer'
  scope: resourceGroup('rg-global-${environment}')
  params: {
    dnsZoneName: dnsZoneName
    trafficManagerName: trafficManagerName
    frontDoorName: frontDoorName
    frontDoorSku: frontDoorSku
    globalLogAnalyticsWorkspaceId: monitoringLayers[0].outputs.logAnalyticsWorkspaceId
    functionAppNamePrefix: functionAppNamePrefix
    functionStorageNamePrefix: functionStorageNamePrefix
    tags: baseTags
    functionAppRegions: functionAppRegions
    globalControlCosmosDbName: globalControlCosmosDbName
    primaryLocation: primaryLocation
    additionalLocations: additionalLocations
    cosmosZoneRedundant: !isSmoke
    enableGlobalFunctions: !isSmoke
    enableGlobalCosmos: !isSmoke
  }
}

// ============ KEY VAULTS ============
module keyVaults './keyvault.bicep' = [
  for (region, index) in regions: {
    name: 'keyVault-${region.geoName}-${region.regionName}'
    scope: resourceGroup('rg-region-${region.geoName}-${region.regionName}')
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
    scope: resourceGroup('rg-region-${region.geoName}-${region.regionName}')
    params: {
      location: region.regionName
      appGatewayName: 'agw-${region.geoName}-${region.regionName}'
      subnetId: regionalNetworks[index].outputs.subnetId
      publicIpId: regionalNetworks[index].outputs.publicIpId
      sslCertSecretId: 'https://${region.keyVaultName}.${az.environment().suffixes.keyvaultDns}/secrets/ssl-cert'
      cellCount: length(region.cells)
      cellBackendFqdns: [for i in range(0, length(region.cells)): 'fa-stamps-${region.regionName}.azurewebsites.net']
      demoBackendFqdn: 'fa-stamps-${region.regionName}.azurewebsites.net'
      enableHttps: !isSmoke
      tags: union(baseTags, {
        geo: region.geoName
        region: region.regionName
      })
      healthProbePath: '/api/health'
      automationAccountName: 'auto-${region.geoName}-${region.regionName}'
    }
    dependsOn: [
      keyVaults
      regionalNetworks
    ]
  }
]

// ============ REGIONAL NETWORK PREREQS ============
module regionalNetworks './regionalNetwork.bicep' = [
  for (region, index) in regions: {
    name: 'regionalNetwork-${region.geoName}-${region.regionName}'
    scope: resourceGroup('rg-region-${region.geoName}-${region.regionName}')
    params: {
      location: region.regionName
      geoName: region.geoName
      regionName: region.regionName
      vnetName: 'vnet-${region.geoName}-${region.regionName}'
      subnetName: 'subnet-agw'
      publicIpName: 'pip-agw-${region.geoName}-${region.regionName}'
      tags: union(baseTags, {
        geo: region.geoName
        region: region.regionName
      })
    }
  }
]

// ============ MONITORING LAYER ============
module monitoringLayers './monitoringLayer.bicep' = [
  for (region, index) in regions: {
    name: 'monitoringLayer-${region.geoName}-${region.regionName}'
    scope: resourceGroup('rg-region-${region.geoName}-${region.regionName}')
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
    scope: resourceGroup('rg-cell-${cell.geoName}-${cell.regionName}-${cell.cellName}')
    params: {
      location: cell.regionName
      sqlServerName: 'sql-${cell.geoName}-${cell.regionName}-${cell.cellName}'
      sqlAdminUsername: sqlAdminUsername
      sqlAdminPassword: sqlAdminPassword
      sqlDbName: 'sqldb-${cell.geoName}-${cell.regionName}-${cell.cellName}'
      storageAccountName: toLower('st${uniqueString(subscription().id, cell.regionName, cell.cellName)}')
      keyVaultName: toLower('kv${uniqueString(subscription().id, 'kv', cell.regionName, cell.cellName)}')
      cosmosDbStampName: 'cosmos-${cell.geoName}-${cell.regionName}-${cell.cellName}'
      tags: union(baseTags, {
        geo: cell.geoName
        region: cell.regionName
        cell: cell.cellName
        availabilityZones: string(length(cell.availabilityZones))
        tenancyModel: toLower(cell.cellType)
        maxTenantCount: string(cell.maxTenantCount)
        workload: 'stamps-pattern'
        costCenter: 'IT-Infrastructure'
      })
      containerRegistryName: 'acr${cell.geoName}${cell.regionName}${cell.cellName}'
      enableContainerRegistry: false
      containerAppName: cell.cellName
      baseDomain: cell.baseDomain
      globalLogAnalyticsWorkspaceId: monitoringLayers[0].outputs.logAnalyticsWorkspaceId
      cosmosAdditionalLocations: cell.?cosmosAdditionalLocations ?? cosmosAdditionalLocations
      cosmosMultiWrite: bool(cell.?cosmosMultiWrite ?? cosmosMultiWrite)
      cosmosZoneRedundant: !isSmoke
      storageSkuName: (cell.?storageSkuName ?? storageSkuName)
      createStorageAccount: false
      enableStorageObjectReplication: bool(cell.?enableStorageObjectReplication ?? enableStorageObjectReplication)
      storageReplicationDestinationId: string(cell.?storageReplicationDestinationId ?? '')
      enableSqlFailoverGroup: bool(cell.?enableSqlFailoverGroup ?? enableSqlFailoverGroup)
      sqlSecondaryServerId: string(cell.?sqlSecondaryServerId ?? '')
      enableCellTrafficManager: false
      diagnosticsMode: isSmoke ? 'metricsOnly' : 'standard'
    }
    dependsOn: [
      regionalLayers
      monitoringLayers
    ]
  }
]

// ============ OUTPUTS ============
output globalLayerOutputs object = globalLayer.outputs

output validationResults object = {
  cellValidation: cellValidation
  tenantValidation: tenantValidation
  allCellsValid: !contains(map(cellValidation, item => item.isValid), false)
  allTenantsValid: !contains(map(tenantValidation, item => item.isValid), false)
}

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
    keyVaultId: deploymentStampLayers[index].outputs.keyVaultId
    keyVaultUri: deploymentStampLayers[index].outputs.keyVaultUri
    sqlServerSystemAssignedPrincipalId: deploymentStampLayers[index].outputs.sqlServerSystemAssignedPrincipalId
    storageAccountSystemAssignedPrincipalId: deploymentStampLayers[index].outputs.storageAccountSystemAssignedPrincipalId
  }
]
