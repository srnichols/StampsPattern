// --------------------------------------------------------------------------------------
// Module: regionalNetwork
// Purpose: Provision per-region networking prerequisites for the regional layer:
// - A VNet with an Application Gateway subnet
// - A Public IP for the Application Gateway
// --------------------------------------------------------------------------------------

@description('Azure region for these network resources')
param location string

@description('Geography name (e.g., northamerica)')
param geoName string

@description('Azure region short name (e.g., eastus)')
param regionName string

@description('Virtual network name')
param vnetName string = 'vnet-${geoName}-${regionName}'

@description('Subnet name for Application Gateway')
param subnetName string = 'subnet-agw'

@description('Public IP name for Application Gateway')
param publicIpName string = 'pip-agw-${geoName}-${regionName}'

@description('Tags to apply to network resources')
param tags object = {}

// Public IP for Application Gateway
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
  tags: tags
}

// Virtual Network with a dedicated subnet for the Application Gateway
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
  tags: tags
}

output publicIpId string = publicIp.id
output subnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
