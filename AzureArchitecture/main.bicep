@description('DNS zone name for the deployment (e.g., stamps.sdp-saas.com)')
param dnsZoneName string = 'stamps.sdp-saas.com'
@description('Traffic Manager profile name')
param trafficManagerName string = 'tm-stamps-global'
@description('Front Door name')
param frontDoorName string = 'fd-stamps-global'
@description('Front Door SKU')
param frontDoorSku string = 'Standard_AzureFrontDoor'
@description('Function App name prefix')
param functionAppNamePrefix string = 'fa-stamps-global-control'
@description('Function Storage name prefix')
param functionStorageNamePrefix string = 'stfastampsglobalcontrol'
@description('Global Control Cosmos DB name')
param globalControlCosmosDbName string = 'global-cosmos-stamps-control'
@description('Additional locations for deployment')
param additionalLocations array = [ 'centralus' ]
@description('Function App regions')
param functionAppRegions array = [ 'westus3', 'centralus' ]
@description('SQL admin username')
param sqlAdminUsername string = 'sqladmin'
@description('SQL admin password')
@secure()
param sqlAdminPassword string
@description('Optional salt to ensure unique resource names for repeated deployments (e.g., date, initials, or random chars)')
param salt string = ''

@description('Deployment environment name (e.g., dev, test, prod)')
@allowed(['dev', 'test', 'staging', 'prod'])
param environment string = 'test'
// Requires Bicep CLI v0.20.0 or later for array filtering with ternary operator
@description('Enable deployment of global Function Apps and their plans/storage (disable in smoke/lab to avoid quota)')
param enableGlobalFunctions bool = true
// APIM and Cosmos DB outputs from geodesLayer
output apimGatewayUrl string = geodesLayer.outputs.apimGatewayUrl
output apimDeveloperPortalUrl string = geodesLayer.outputs.apimDeveloperPortalUrl
output apimManagementApiUrl string = geodesLayer.outputs.apimManagementApiUrl
output apimResourceId string = geodesLayer.outputs.apimResourceId
output globalControlCosmosDbEndpoint string = geodesLayer.outputs.globalControlCosmosDbEndpoint
output globalControlCosmosDbId string = geodesLayer.outputs.globalControlCosmosDbId
// Filter out regional endpoints with empty FQDNs for Traffic Manager
// The filteredRegionalEndpoints variable has been removed as part of the patch.

// Azure Stamps Pattern - Main Orchestration Template
//
// 📚 Documentation:
// - Architecture Overview: ../docs/ARCHITECTURE_GUIDE.md
// - Deployment Guide: ../docs/DEPLOYMENT_ARCHITECTURE_GUIDE.md
// - Developer Quickstart: ../docs/DEVELOPER_QUICKSTART.md
//
// 📝 Notes for Developers:
// - This is the top-level entry point for orchestrating all resource groups and modules in a Stamps Pattern deployment.
// - Naming conventions for RGs, assets, and zones are enforced for automation and compliance. See docs for rationale.
// - The deployment expects all required parameters to be set in main.parameters.json.
// - For local development or testing, see the Developer Quickstart for emulator and tool setup.
//
// ⚠️ Prerequisites:
// - Review and update the regions/cells arrays to match your intended topology.
// - Ensure you have the correct app registration IDs for managementClientAppId and managementClientTenantId.
// - Some modules (e.g., globalLayer, regionalLayer) have their own parameter requirements—see their files for details.
//
// For more, see the docs above or ask in the project discussions.

targetScope = 'subscription'
// Create a resource group for global assets
resource globalResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-stamps-global-${environment}'
  location: primaryLocation
  tags: union(baseTags, { scope: 'global' })
}

// Create a resource group for each region
resource regionResourceGroups 'Microsoft.Resources/resourceGroups@2021-04-01' = [for region in regions: {
  name: 'rg-stamps-region-${region.geoName}-${region.regionName}-${environment}'
  location: region.regionName
  tags: union(baseTags, { geo: region.geoName, region: region.regionName, scope: 'region' })
}]

// Create a resource group for each CELL
resource cellResourceGroups 'Microsoft.Resources/resourceGroups@2021-04-01' = [for (cell, index) in cells: {
  name: 'rg-stamps-cell-${cell.geoName}-${cell.regionName}-CELL-${padLeft(string(index + 1), 2, '0')}-${environment}'
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
  // Create a resource group for each CELL

// ============ PARAMETERS ============
// Management Portal App Registration
@description('Application (client) ID for the StampsManagementClient enterprise app registration')
param managementClientAppId string
@description('Entra ID Tenant ID for the StampsManagementClient enterprise app registration')
param managementClientTenantId string

// Organization Parameters
@description('The organization domain (e.g., sdp-saas.com)')
param organizationDomain string = 'sdp-saas.com'
@description('The base DNS zone name (without domain)')
param baseDnsZoneName string = 'stamps'

@description('The department responsible for the deployment')
param department string = 'IT'

@description('The project name for resource tagging and naming')
param projectName string = 'StampsPattern'

@description('The workload name for resource tagging')
param workloadName string = 'stamps-pattern'

@description('The owner email for resource tagging')
param ownerEmail string = 'platform-team@sdp-saas.com'

// Geography Parameters
@description('Primary Azure region for global resources')
param primaryLocation string = 'westus3'
param regions array = [
  {
    geoName: 'na'
    regionName: 'westus3'
    cells: [ 'cell-01', 'cell-02', 'cell-03' ]
    baseDomain: 'westus3.${baseDnsZoneName}.${organizationDomain}'
    keyVaultName: 'kv-stamps-na-westus3${empty(salt) ? '' : salt}'
    logAnalyticsWorkspaceName: 'law-stamps-na-westus3'
  }
  {
    geoName: 'na'
    regionName: 'centralus'
    cells: [ 'cell-01', 'cell-02', 'cell-03' ]
    baseDomain: 'centralus.${baseDnsZoneName}.${organizationDomain}'
    keyVaultName: 'kv-stamps-na-centralus${empty(salt) ? '' : salt}'
    logAnalyticsWorkspaceName: 'law-stamps-na-centralus'
  }
]
@maxValue(3)
param minAvailabilityZones int = 1

@description('Maximum tenants allowed per shared CELL')
param cells array = [
  {
    geoName: 'na'
    regionName: 'westus3'
    cellName: 'CELL-01'
    cellType: 'Shared'
    availabilityZones: []
    maxTenantCount: 100
    baseDomain: 'westus3.${baseDnsZoneName}.${organizationDomain}'
    logAnalyticsWorkspaceName: 'law-stamps-na-westus3'
    keyVaultName: 'kv-stamps-na-westus3${empty(salt) ? '' : salt}'
  }
  {
    geoName: 'na'
    regionName: 'westus3'
    cellName: 'CELL-02'
    cellType: 'Shared'
    availabilityZones: [ '1', '2' ]
    maxTenantCount: 100
    baseDomain: 'westus3.${baseDnsZoneName}.${organizationDomain}'
    logAnalyticsWorkspaceName: 'law-stamps-na-westus3'
    keyVaultName: 'kv-stamps-na-westus3${empty(salt) ? '' : salt}'
  }
  {
    geoName: 'na'
    regionName: 'westus3'
    cellName: 'CELL-03'
    cellType: 'Dedicated'
    availabilityZones: [ '1', '2', '3' ]
    maxTenantCount: 1
    baseDomain: 'westus3.${baseDnsZoneName}.${organizationDomain}'
    logAnalyticsWorkspaceName: 'law-stamps-na-westus3'
    keyVaultName: 'kv-stamps-na-westus3${empty(salt) ? '' : salt}'
  }
  {
    geoName: 'na'
    regionName: 'centralus'
    cellName: 'CELL-01'
    cellType: 'Dedicated'
    availabilityZones: []
    maxTenantCount: 1
    baseDomain: 'centralus.${baseDnsZoneName}.${organizationDomain}'
    logAnalyticsWorkspaceName: 'law-stamps-na-centralus'
    keyVaultName: 'kv-stamps-na-centralus${empty(salt) ? '' : salt}'
  }
  {
    geoName: 'na'
    regionName: 'centralus'
    cellName: 'CELL-02'
    cellType: 'Shared'
    availabilityZones: [ '1', '2' ]
    maxTenantCount: 100
    baseDomain: 'centralus.${baseDnsZoneName}.${organizationDomain}'
    logAnalyticsWorkspaceName: 'law-stamps-na-centralus'
    keyVaultName: 'kv-stamps-na-centralus${empty(salt) ? '' : salt}'
  }

   {
     geoName: 'na'
     regionName: 'centralus'
     cellName: 'CELL-03'
     cellType: 'Dedicated'
     availabilityZones: [ '1', '2', '3' ]
     maxTenantCount: 1
     baseDomain: 'centralus.${baseDnsZoneName}.${organizationDomain}'
     logAnalyticsWorkspaceName: 'law-stamps-na-centralus'
     keyVaultName: 'kv-stamps-na-centralus${empty(salt) ? '' : salt}'
   }
]

// @description('Use HTTP for Application Gateway listeners in lab/smoke (no Key Vault cert required)')
// param useHttpForSmoke bool = true

// Derived flag: treat either explicit useHttpForSmoke or environmentProfile==smoke as smoke mode
// var isSmoke = useHttpForSmoke || environmentProfile == 'smoke'

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

@description('Whether Cosmos DB regions should be zone redundant (set false for lab/smoke in constrained regions)')

// ============ VARIABLES ============
// Key Vault names: max 24 chars, alphanumeric, start with letter, end with letter/digit
var keyVaultNames = [for (region, index) in regions: take(toLower('kvs${take(region.regionName, 3)}${take(environment, 1)}${substring(uniqueString(subscription().id, 'kv', region.regionName, environment), 0, 8)}${replace(replace(take(salt, 6), '-', ''), '_', '')}'), 24)]
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
// var tenantValidation = [for cell in cells: {
//   isValid: cell.cellType == 'Dedicated' || cell.maxTenantCount <= maxTenantsPerSharedCell
//   cellName: cell.cellName
//   tenantCount: cell.maxTenantCount
// }]

// ============ GEODES LAYER (APIM & Global Control Plane) ============
// Deploy this first as it's needed for global layer configuration
module geodesLayer './geodesLayer.bicep' = {
  name: 'geodesLayer'
  scope: resourceGroup('rg-stamps-global-${environment}')
  params: {
    location: primaryLocation
  apimName: 'apim-stamps-global-${environment}${empty(salt) ? '' : '-${salt}'}'
    apimPublisherEmail: ownerEmail
    apimPublisherName: department
    apimAdditionalRegions: additionalLocations
    customDomain: '' // Set if you want a custom APIM domain
    tags: baseTags
    globalLogAnalyticsWorkspaceId: monitoringLayers[0].outputs.logAnalyticsWorkspaceId
    globalControlCosmosDbName: globalControlCosmosDbName
    primaryLocation: primaryLocation
    additionalLocations: additionalLocations
    cosmosZoneRedundant: false
    entraTenantId: managementClientTenantId
  }
  dependsOn: [
    monitoringLayers
  ]
}

// ============ KEY VAULTS ============
module keyVaults './keyvault.bicep' = [
  for (region, index) in regions: {
    name: 'keyVault-${region.geoName}-${region.regionName}'
    scope: resourceGroup('rg-stamps-region-${region.geoName}-${region.regionName}-${environment}')
    params: {
      name: keyVaultNames[index]
      location: region.regionName
      skuName: 'standard'
      tags: union(baseTags, {
        geo: region.geoName
        region: region.regionName
      })
      accessPolicies: [
        {
          tenantId: subscription().tenantId
          objectId: regionalUserAssignedIdentities[index].outputs.principalId
          permissions: {
            secrets: [ 'get', 'list' ]
          }
        }
      ]
    }
  }
]

// Provision a placeholder ssl-cert secret in each Key Vault for Application Gateway
module keyVaultSecrets './keyvaultSecret.bicep' = [
  for (region, index) in regions: {
    name: 'keyVaultSecret-${region.geoName}-${region.regionName}'
    scope: resourceGroup('rg-stamps-region-${region.geoName}-${region.regionName}-${environment}')
    params: {
      keyVaultName: keyVaultNames[index]
      secretName: 'ssl-cert'
      secretValue: 'PLACEHOLDER-REPLACE-ME'
    }
    dependsOn: [
      keyVaults
    ]
  }
]

// ============ REGIONAL LAYER ============
// Create a user-assigned managed identity for each region
module regionalUserAssignedIdentities './managedIdentity.bicep' = [
  for (region, index) in regions: {
    name: 'regionalUserAssignedIdentity-${region.geoName}-${region.regionName}'
    scope: resourceGroup('rg-stamps-region-${region.geoName}-${region.regionName}-${environment}')
    params: {
      name: 'agw-identity-${region.geoName}-${region.regionName}-${environment}'
      location: region.regionName
      tags: union(baseTags, {
        geo: region.geoName
        region: region.regionName
        scope: 'region-agw-identity'
      })
    }
  }
]

module regionalLayers './regionalLayer.bicep' = [
  for (region, index) in regions: {
    name: 'regionalLayer-${region.geoName}-${region.regionName}'
    scope: resourceGroup('rg-stamps-region-${region.geoName}-${region.regionName}-${environment}')
    params: {
      location: region.regionName
      appGatewayName: 'agw-${region.geoName}-${region.regionName}'
      subnetId: regionalNetworks[index].outputs.subnetId
      publicIpId: regionalNetworks[index].outputs.publicIpId
  sslCertSecretId: ''
  enableHttps: false
    userAssignedIdentityId: regionalUserAssignedIdentities[index].outputs.id
      cellCount: length(region.cells)
      cellBackendFqdns: [for i in range(0, length(region.cells)): 'fa-stamps-${region.regionName}.azurewebsites.net']
      demoBackendFqdn: 'fa-stamps-${region.regionName}.azurewebsites.net'
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
      regionalUserAssignedIdentities
    ]
  }
]

// ============ GLOBAL LAYER ============


// Deploy this after APIM and regional layers to configure traffic routing
module globalLayer './globalLayer.bicep' = {
  name: 'globalLayer'
  scope: resourceGroup('rg-stamps-global-${environment}')
  params: {
    dnsZoneName: dnsZoneName
    trafficManagerName: trafficManagerName
    frontDoorName: frontDoorName
    frontDoorSku: frontDoorSku
    globalLogAnalyticsWorkspaceId: monitoringLayers[0].outputs.logAnalyticsWorkspaceId
    globalLogAnalyticsWorkspaceKeyVaultSecretUri: monitoringLayers[0].outputs.logAnalyticsWorkspaceKeyVaultSecretUri
    functionAppNamePrefix: functionAppNamePrefix
    functionStorageNamePrefix: functionStorageNamePrefix
    tags: baseTags
    functionAppRegions: functionAppRegions
    globalControlCosmosDbName: globalControlCosmosDbName
    primaryLocation: primaryLocation
    additionalLocations: additionalLocations
    // cosmosZoneRedundant: !isSmoke
    enableGlobalFunctions: enableGlobalFunctions
    // enableGlobalCosmos: !isSmoke
    // Pass APIM gateway URL for Front Door configuration
    apimGatewayUrl: geodesLayer.outputs.apimGatewayUrl
    // Pass all regional Application Gateway endpoints for Traffic Manager (filtering will be done in globalLayer.bicep)
    regionalEndpoints: [
      for (region, i) in regions: !empty(regionalLayers[i].outputs.regionalEndpointFqdn) ? {
        fqdn: regionalLayers[i].outputs.regionalEndpointFqdn
        location: region.regionName
      } : null
    ]
    keyVaultName: regions[0].keyVaultName
  }
  dependsOn: [
    regionalLayers
    monitoringLayers
  ]
}

// ============ REGIONAL NETWORK PREREQS ============
module regionalNetworks './regionalNetwork.bicep' = [
  for (region, index) in regions: {
    name: 'regionalNetwork-${region.geoName}-${region.regionName}'
  scope: resourceGroup('rg-stamps-region-${region.geoName}-${region.regionName}-${environment}')
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
    scope: resourceGroup('rg-stamps-region-${region.geoName}-${region.regionName}-${environment}')
    params: {
      location: region.regionName
      logAnalyticsWorkspaceName: region.logAnalyticsWorkspaceName
      retentionInDays: 30
      tags: union(baseTags, {
        geo: region.geoName
        region: region.regionName
      })
      keyVaultName: keyVaults[index].outputs.vaultName
    }
    dependsOn: [
      keyVaults
    ]
  }
]

// ============ DEPLOYMENT STAMP LAYER (CELLS) ============
module deploymentStampLayers './deploymentStampLayer.bicep' = [
  for (cell, index) in cells: {
    name: 'deploymentStampLayer-${cell.geoName}-${cell.regionName}-CELL-${padLeft(string(index + 1), 2, '0')}'
    scope: resourceGroup('rg-stamps-cell-${cell.geoName}-${cell.regionName}-CELL-${padLeft(string(index + 1), 2, '0')}-${environment}')
    params: {
      location: cell.regionName
      sqlServerName: 'sql-${cell.geoName}-${cell.regionName}-CELL-${padLeft(string(index + 1), 2, '0')}-z${string(length(cell.availabilityZones))}'
      sqlAdminUsername: sqlAdminUsername
      sqlAdminPassword: sqlAdminPassword
      sqlDbName: 'sqldb-${cell.geoName}-${cell.regionName}-CELL-${padLeft(string(index + 1), 2, '0')}-z${string(length(cell.availabilityZones))}'
      storageAccountName: toLower('st${uniqueString(subscription().id, cell.regionName, 'CELL-${padLeft(string(index + 1), 2, '0')}')}z${string(length(cell.availabilityZones))}')
      // Key Vault name: max 24 chars, alphanumeric only, must start with letter, end with letter/digit
      // Example: kvs-wus2-p-abc123de
  keyVaultName: take(toLower('kvs${take(cell.regionName, 3)}${take(environment, 1)}${substring(uniqueString(subscription().id, 'kv', cell.regionName, environment, 'CELL-${padLeft(string(index + 1), 2, '0')}'), 0, 6)}${replace(replace(take(salt, 4), '-', ''), '_', '')}'), 24)
      salt: salt
      // Cosmos DB name: 3-44 chars, lowercase, letters, numbers, hyphens only, must start with a letter
      cosmosDbStampName: toLower('cosmos${take(cell.geoName, 3)}${take(cell.regionName, 3)}${padLeft(string(index + 1), 2, '0')}z${string(length(cell.availabilityZones))}${substring(uniqueString(subscription().id, cell.geoName, cell.regionName, string(index)), 0, 6)}')
      tags: union(baseTags, {
        geo: cell.geoName
        region: cell.regionName
        cell: 'CELL-${padLeft(string(index + 1), 2, '0')}'
        availabilityZones: string(length(cell.availabilityZones))
        tenancyModel: toLower(cell.cellType)
        maxTenantCount: string(cell.maxTenantCount)
        workload: 'stamps-pattern'
        costCenter: 'IT-Infrastructure'
      })
      containerRegistryName: 'acr${cell.geoName}${cell.regionName}CELL${padLeft(string(index + 1), 2, '0')}'
      enableContainerRegistry: false
      containerAppName: 'CELL-${padLeft(string(index + 1), 2, '0')}'
      containerAppEnvironmentName: 'cae-${cell.regionName}-${toLower(cell.cellName)}-${environment}-${take(subscription().subscriptionId, 8)}'
      baseDomain: cell.baseDomain
  globalLogAnalyticsWorkspaceId: monitoringLayers[0].outputs.logAnalyticsWorkspaceId
  globalLogAnalyticsWorkspaceKeyVaultSecretUri: monitoringLayers[0].outputs.logAnalyticsWorkspaceKeyVaultSecretUri
      cosmosAdditionalLocations: cell.?cosmosAdditionalLocations ?? cosmosAdditionalLocations
      cosmosMultiWrite: bool(cell.?cosmosMultiWrite ?? cosmosMultiWrite)
  cosmosZoneRedundant: false
      storageSkuName: (cell.?storageSkuName ?? storageSkuName)
      createStorageAccount: true
      enableStorageObjectReplication: bool(cell.?enableStorageObjectReplication ?? enableStorageObjectReplication)
      storageReplicationDestinationId: string(cell.?storageReplicationDestinationId ?? '')
      enableSqlFailoverGroup: bool(cell.?enableSqlFailoverGroup ?? enableSqlFailoverGroup)
      sqlSecondaryServerId: string(cell.?sqlSecondaryServerId ?? '')
      enableCellTrafficManager: false
      // diagnosticsMode: isSmoke ? 'metricsOnly' : 'standard'
    }
    dependsOn: [
      regionalLayers
      monitoringLayers
    ]
  }
]






// ============ MANAGEMENT PORTAL RESOURCE GROUP ============
resource managementPortalResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-stamps-management-portal-${environment}'
  location: primaryLocation
  tags: union(baseTags, {
    scope: 'management-portal'
    managementClientAppId: managementClientAppId
    managementClientTenantId: managementClientTenantId
  })
}

// ============ OUTPUTS ============
output globalLayerOutputs object = globalLayer.outputs

output validationResults object = {
  cellValidation: cellValidation
  // tenantValidation: tenantValidation
  allCellsValid: !contains(map(cellValidation, item => item.isValid), false)
  // allTenantsValid: !contains(map(tenantValidation, item => item.isValid), false)
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
    cellName: 'CELL-${padLeft(string(index + 1), 2, '0')}'
    keyVaultId: deploymentStampLayers[index].outputs.keyVaultId
    keyVaultUri: deploymentStampLayers[index].outputs.keyVaultUri
    sqlServerSystemAssignedPrincipalId: deploymentStampLayers[index].outputs.sqlServerSystemAssignedPrincipalId
    storageAccountSystemAssignedPrincipalId: deploymentStampLayers[index].outputs.storageAccountSystemAssignedPrincipalId
  }
]

output managementPortalDeploymentParams object = {
  resourceGroupName: managementPortalResourceGroup.name
  location: managementPortalResourceGroup.location
  environment: environment
  managementClientAppId: managementClientAppId
  managementClientTenantId: managementClientTenantId
  subscriptionId: subscription().subscriptionId
}
