# Deploy only regional networks and Application Gateways (skip cells to avoid SQL issues)
param(
  [string]$SubscriptionId = '2fb123ca-e419-4838-9b44-c2eb71a21769',
  [string]$ResourceGroup = 'rg-stamps-host',
  [string]$GlobalLawId = '/subscriptions/480cb033-9a92-4912-9d30-c6b7bf795a87/resourceGroups/rg-stamps-hub/providers/Microsoft.OperationalInsights/workspaces/law-stamps-hub-2rl64hudjvcpq',
  [string]$DemoBackend = 'www.bing.com'
)

$ErrorActionPreference = 'Stop'
az account set --subscription $SubscriptionId | Out-Null

# Create a simplified template that only deploys regional layers
$simplifiedTemplate = @"
targetScope = 'resourceGroup'

@description('Tags to apply to all resources')
param tags object = {}

@description('Array of regions to deploy')
param regions array

@description('The resource ID of the central Log Analytics Workspace')
param globalLogAnalyticsWorkspaceId string

@description('Demo backend FQDN')
param demoBackendFqdn string = 'www.bing.com'

var envShort = 'tst'
var regionShortNames = { westus2: 'wus2', westus3: 'wus3' }
var geoShortNames = { northamerica: 'us' }

// Regional Key Vaults (existing ones)
var regionalKvNames = [
  for (region, idx) in regions: toLower('kv-' + (geoShortNames[?region.geoName] ?? 'us') + '-' + (regionShortNames[?region.regionName] ?? 'reg') + '-' + envShort + '-' + substring(uniqueString(resourceGroup().id, region.regionName, 'agw-kv'), 0, 4))
]

// Reference existing UAMIs  
resource uamis 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = [for (region, idx) in regions: {
  name: 'uami-agw-' + (regionShortNames[?region.regionName] ?? 'reg') + '-' + envShort
}]

// Reference existing Key Vaults
resource regionalKeyVaults 'Microsoft.KeyVault/vaults@2023-02-01' existing = [for (region, idx) in regions: {
  name: regionalKvNames[idx]
}]

// Regional networks
module regionalNetworks './regionalNetwork.bicep' = [for (region, idx) in regions: {
  name: 'regionalNetwork-' + region.geoName + '-' + region.regionName
  params: {
    location: region.regionName
    geoName: region.geoName
    regionName: region.regionName
    vnetName: 'vnet-stamps-' + (regionShortNames[?region.regionName] ?? 'reg') + '-' + envShort
    subnetName: 'snet-agw-' + (regionShortNames[?region.regionName] ?? 'reg') + '-' + envShort
    publicIpName: 'pip-agw-' + (regionShortNames[?region.regionName] ?? 'reg') + '-' + envShort
    publicIpDnsLabel: toLower('agw-' + (regionShortNames[?region.regionName] ?? 'reg') + '-' + envShort + '-' + substring(uniqueString(resourceGroup().id, region.regionName, 'pip'), 0, 4))
    tags: union(tags, { geo: region.geoName, region: region.regionName })
  }
}]

// Regional layers (Application Gateways)
module regionalLayers './regionalLayer.bicep' = [for (region, idx) in regions: {
  name: 'regional-' + region.geoName + '-' + region.regionName
  params: {
    location: region.regionName
    appGatewayName: 'agw-' + (geoShortNames[?region.geoName] ?? 'us') + '-' + (regionShortNames[?region.regionName] ?? 'reg') + '-' + envShort
    subnetId: regionalNetworks[idx].outputs.subnetId
    publicIpId: regionalNetworks[idx].outputs.publicIpId
    sslCertSecretId: uri(regionalKeyVaults[idx].properties.vaultUri, 'secrets/ssl-cert')
    cellCount: 3  // Fixed for testing
    cellBackendFqdns: ['cell1.demo.local', 'cell2.demo.local', 'cell3.demo.local']
    demoBackendFqdn: demoBackendFqdn
    enableHttps: true
    userAssignedIdentityId: uamis[idx].id
    healthProbePath: '/'
    automationAccountName: 'auto-' + (geoShortNames[?region.geoName] ?? 'us') + '-' + (regionShortNames[?region.regionName] ?? 'reg') + '-' + envShort
    tags: union(tags, { geo: region.geoName, region: region.regionName })
  }
}]
"@

# Save simplified template
$tempTemplate = 'temp-gateways-only.bicep'
$simplifiedTemplate | Out-File -FilePath $tempTemplate -Encoding UTF8

# Deploy
$ts = Get-Date -Format yyyyMMddHHmmss
Write-Host "Deploying gateways-only-$ts..." -ForegroundColor Green

az deployment group create `
  --resource-group $ResourceGroup `
  --template-file $tempTemplate `
  --parameters regions='[{"geoName":"northamerica","regionName":"westus2"},{"geoName":"northamerica","regionName":"westus3"}]' `
  --parameters globalLogAnalyticsWorkspaceId=$GlobalLawId `
               demoBackendFqdn=$DemoBackend `
               tags='{"environment":"test"}' `
  --name gateways-only-$ts -o table

# Cleanup
Remove-Item $tempTemplate -Force
