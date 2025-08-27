targetScope = 'subscription'
// resourceGroups.bicep
// This Bicep file creates all required resource groups for the Stamps Pattern deployment.
// Deploy this file at the subscription scope before deploying main.bicep.

param environment string
param primaryLocation string
param regions array
param cells array
param baseTags object = {}

// Global resource group
resource globalResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-stamps-global-${environment}'
  location: primaryLocation
  tags: union(baseTags, { scope: 'global' })
}

// Regional resource groups
resource regionResourceGroups 'Microsoft.Resources/resourceGroups@2021-04-01' = [for region in regions: {
  name: 'rg-stamps-region-${region.geoName}-${region.regionName}-${environment}'
  location: region.regionName
  tags: union(baseTags, { geo: region.geoName, region: region.regionName, scope: 'region' })
}]

// Cell resource groups
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


// Management Portal resource group
resource managementPortalResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-stamps-management-portal-${environment}'
  location: primaryLocation
  tags: union(baseTags, {
    scope: 'management-portal'
    // managementClientAppId and managementClientTenantId are not needed for RG creation
  })
}


// Deploy managed identity into the global resource group using a module
module globalIdentityModule './globalIdentity.module.bicep' = {
  name: 'globalIdentityModule'
  scope: resourceGroup(globalResourceGroup.name)
  params: {
    location: primaryLocation
    identityName: 'global-deployment-identity'
  }
}

output globalIdentityResourceId string = globalIdentityModule.outputs.identityResourceId
output globalIdentityPrincipalId string = globalIdentityModule.outputs.principalId
