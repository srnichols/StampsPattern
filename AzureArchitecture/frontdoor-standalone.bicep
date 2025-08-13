// Standalone Azure Front Door Standard deployment for the Stamps Pattern
// This deploys only the Front Door components without touching existing Traffic Manager or other global resources

targetScope = 'resourceGroup'

@description('Name of the Front Door profile')
param frontDoorName string

@description('Azure Front Door SKU - Standard_AzureFrontDoor or Premium_AzureFrontDoor')
@allowed(['Standard_AzureFrontDoor', 'Premium_AzureFrontDoor'])
param frontDoorSku string = 'Standard_AzureFrontDoor'

@description('Array of regional endpoint FQDNs for Front Door origins')
param regionalEndpoints array = []

@description('Tags for resource management')
param tags object = {}

@description('The resource ID of the Log Analytics Workspace for diagnostics')
param logAnalyticsWorkspaceId string

// Modern Azure Front Door Profile (Standard/Premium)
resource frontDoor 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: frontDoorName
  location: 'global'
  sku: {
    name: frontDoorSku
  }
  tags: tags
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

// Front Door Endpoint
resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  name: 'stamps-global-endpoint'
  parent: frontDoor
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

// Origin Group for regional Application Gateways
resource originGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = if (length(regionalEndpoints) > 0) {
  name: 'regional-agw-origins'
  parent: frontDoor
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'GET'
      probeProtocol: 'Http'  // Changed from Https to Http
      probeIntervalInSeconds: 100
    }
  }
}

// Origins for each regional Application Gateway
resource origins 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = [for (endpoint, i) in regionalEndpoints: if (length(regionalEndpoints) > 0) {
  name: 'agw-${endpoint.location}-origin'
  parent: originGroup
  properties: {
    hostName: endpoint.fqdn
    httpPort: 80
    httpsPort: 443
    originHostHeader: endpoint.fqdn
    priority: (i % 5) + 1  // Ensure priority is between 1-5
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: false  // Disabled for self-signed certificates
  }
}]

// Route to forward traffic to regional Application Gateways
resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = if (length(regionalEndpoints) > 0) {
  name: 'regional-route'
  parent: frontDoorEndpoint
  properties: {
    customDomains: []
    originGroup: {
      id: originGroup.id
    }
    originPath: null
    ruleSets: []
    supportedProtocols: ['Http', 'Https']
    patternsToMatch: ['/*']
    forwardingProtocol: 'MatchRequest'  // Changed from HttpsOnly to MatchRequest
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
  dependsOn: [
    origins
  ]
}

// Diagnostics for Front Door
resource frontDoorDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'frontdoor-diagnostics'
  scope: frontDoor
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'FrontdoorAccessLog'
        enabled: true
      }
      {
        category: 'FrontdoorWebApplicationFirewallLog'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Outputs
output frontDoorProfileName string = frontDoor.name
output frontDoorEndpointHostname string = frontDoorEndpoint.properties.hostName
output frontDoorEndpointId string = frontDoorEndpoint.id
output message string = 'Azure Front Door ${frontDoorSku} deployed successfully'
