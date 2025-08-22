// Parameters
@description('Environment name (e.g., dev, test, prod)')
param environment string = 'dev'

@description('Location for resources')
param location string = resourceGroup().location

@description('Resource name prefix')
param resourcePrefix string = 'stamps'

@description('Publisher email for API Management')
param publisherEmail string = 'admin@sdp-saas.com'

@description('Publisher name for API Management')
param publisherName string = 'Contoso'

@description('Subscription ID')
param subscriptionId string = subscription().subscriptionId

@description('Resource Group name')
param resourceGroupName string = resourceGroup().name

@description('SQL admin username')
param sqlAdminUsername string = 'sqladmin'

@secure()
@description('SQL admin password')
param sqlAdminPassword string

@description('Base domain for the stamps')
param baseDomain string = 'sdp-saas.com'

@description('Log Analytics Workspace ID for monitoring')
param logAnalyticsWorkspaceId string = '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.OperationalInsights/workspaces/myLogAnalyticsWorkspace'

@description('Enable APIM Premium tier for enterprise features')
param enablePremiumApim bool = true

@description('Additional regions for APIM multi-region deployment')
param apimAdditionalRegions array = [
  {
    location: 'westeurope'
    capacity: 1
    zones: ['1', '2']
  }
]

// Variables
// Region mapping for short names
var regionShortNames = {
  eastus: 'eus'
  eastus2: 'eus2'
  westus: 'wus'
  westus2: 'wus2'
  westus3: 'wus3'
  centralus: 'cus'
  northeurope: 'neu'
  westeurope: 'weu'
  francecentral: 'frc'
  germanywestcentral: 'gwc'
  uksouth: 'uks'
  southeastasia: 'sea'
  eastasia: 'ea'
  japaneast: 'jpe'
  australiaeast: 'aue'
  centralindia: 'cin'
}

var regionShort = regionShortNames[?location] ?? take(location, 3)
var trafficManagerName = '${resourcePrefix}-tm-${environment}'
var frontDoorName = '${resourcePrefix}-fd-${environment}'
var apimName = '${resourcePrefix}-apim-${regionShort}-${environment}'
var cosmosDbName = '${resourcePrefix}-cosmos-${regionShort}-${environment}'
var appGatewayName = '${resourcePrefix}-agw-${regionShort}-${environment}'
var monitoringName = '${resourcePrefix}-ai-${regionShort}-${environment}'
var managementName = '${resourcePrefix}-auto-${regionShort}-${environment}'

resource trafficManager 'Microsoft.Network/trafficmanagerprofiles@2022-04-01' = {
  name: trafficManagerName
  location: 'global'
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Performance'
    dnsConfig: {
      relativeName: 'mytrafficmanager'
      ttl: 30
    }
    monitorConfig: {
      protocol: 'HTTP'
      port: 80
      path: '/health'
    }
    endpoints: [
      {
        name: 'endpoint1'
        type: 'Microsoft.Network/trafficmanagerprofiles/externalEndpoints'
        properties: {
          target: 'endpoint1.sdp-saas.com'
          endpointStatus: 'Enabled'
          weight: 1
          priority: 1
          endpointLocation: 'East US'
        }
      }
      {
        name: 'endpoint2'
        type: 'Microsoft.Network/trafficmanagerprofiles/externalEndpoints'
        properties: {
          target: 'endpoint2.sdp-saas.com'
          endpointStatus: 'Enabled'
          weight: 1
          priority: 2
          endpointLocation: 'West US'
        }
      }
    ]
  }
}
  
resource frontDoor 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: frontDoorName
  location: 'global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
  properties: {}
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  name: '${frontDoorName}-endpoint'
  parent: frontDoor
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}
  
// Enhanced Geodes Layer with Enterprise APIM
module geodesLayer './AzureArchitecture/geodesLayer.bicep' = {
  name: 'geodesLayer'
  params: {
    location: location
    apimName: apimName
    apimPublisherEmail: publisherEmail
    apimPublisherName: publisherName
    apimAdditionalRegions: enablePremiumApim ? apimAdditionalRegions : []
    customDomain: 'api.${baseDomain}'
    tags: {
      environment: environment
      solution: 'stamps-pattern'
      purpose: 'api-management'
    }
    globalLogAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    globalControlCosmosDbName: cosmosDbName
    primaryLocation: location
    additionalLocations: enablePremiumApim ? [
      {
        locationName: location == 'eastus' ? 'westus' : 'eastus'
        failoverPriority: 1
      }
    ] : []
  }
}

// Application Gateway - Simplified version
// Note: Requires virtual network and public IP to be created separately
resource appGateway 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: appGatewayName
  location: location
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Network/virtualNetworks/myVnet/subnets/mySubnet'
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIp'
        properties: {
          publicIPAddress: {
            id: '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Network/publicIPAddresses/myPublicIp'
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'appGatewayFrontendPort'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'appGatewayBackendPool'
        properties: {
          backendAddresses: [
            {
              fqdn: 'backend1.sdp-saas.com'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'appGatewayHttpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'appGatewayHttpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'appGatewayFrontendPort')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'appGatewayRoutingRule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'appGatewayHttpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'appGatewayBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'appGatewayHttpSettings')
          }
        }
      }
    ]
  }
}
  
// Deployment Stamps - Multiple isolated application instances
module deploymentStamp1 './AzureArchitecture/deploymentStampLayer.bicep' = {
  name: 'deploymentStamp1'
  params: {
    location: 'eastus'
    sqlServerName: '${resourcePrefix}-sql-stamp1-${environment}'
    sqlAdminUsername: sqlAdminUsername
    sqlAdminPassword: sqlAdminPassword
    sqlDbName: '${resourcePrefix}-db-stamp1-${environment}'
    storageAccountName: '${resourcePrefix}stg${regionShort}1${environment}'
    cosmosDbStampName: '${resourcePrefix}-cosmos-stamp1-${environment}'
  containerRegistryName: toLower('acr${location}${environment}stamp1')
    containerAppName: '${resourcePrefix}-app-stamp1-${environment}'
    baseDomain: baseDomain
    globalLogAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    tags: {
      environment: environment
      stamp: 'stamp1'
    }
  }
}

module deploymentStamp2 './AzureArchitecture/deploymentStampLayer.bicep' = {
  name: 'deploymentStamp2'
  params: {
    location: 'westus'
    sqlServerName: '${resourcePrefix}-sql-stamp2-${environment}'
    sqlAdminUsername: sqlAdminUsername
    sqlAdminPassword: sqlAdminPassword
    sqlDbName: '${resourcePrefix}-db-stamp2-${environment}'
    storageAccountName: '${resourcePrefix}stg${regionShort}2${environment}'
    cosmosDbStampName: '${resourcePrefix}-cosmos-stamp2-${environment}'
  containerRegistryName: toLower('acr${location}${environment}stamp2')
    containerAppName: '${resourcePrefix}-app-stamp2-${environment}'
    baseDomain: baseDomain
    globalLogAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    tags: {
      environment: environment
      stamp: 'stamp2'
    }
  }
}
  
resource monitoring 'Microsoft.Insights/components@2020-02-02' = {
  name: monitoringName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.OperationalInsights/workspaces/myLogAnalyticsWorkspace'
  }
}

resource management 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: managementName
  location: location
  properties: {
    sku: {
      name: 'Free'
    }
  }
}

// Outputs for important resource information
@description('Traffic Manager FQDN')
output trafficManagerFqdn string = trafficManager.properties.dnsConfig.fqdn

@description('Front Door endpoint hostname')
output frontDoorEndpointHostname string = frontDoorEndpoint.properties.hostName

@description('API Management gateway URL')
output apimGatewayUrl string = geodesLayer.outputs.apimGatewayUrl

@description('API Management developer portal URL')
output apimDeveloperPortalUrl string = geodesLayer.outputs.apimDeveloperPortalUrl

@description('Cosmos DB endpoint')
output cosmosDbEndpoint string = geodesLayer.outputs.globalControlCosmosDbEndpoint

@description('Application Insights instrumentation key')
output appInsightsInstrumentationKey string = monitoring.properties.InstrumentationKey

@description('Deployment Stamp 1 outputs')
output deploymentStamp1Outputs object = deploymentStamp1.outputs

@description('Deployment Stamp 2 outputs')
output deploymentStamp2Outputs object = deploymentStamp2.outputs
  