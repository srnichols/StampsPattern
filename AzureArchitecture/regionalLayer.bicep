// --------------------------------------------------------------------------------------
// Module: regionalLayer
// Purpose: Provisions region-specific infrastructure such as Application Gateway, networking, and automation.
//          Configures backend addresses, public IP, SSL certificate, tags, and Automation Account.
//          Outputs the public IP address and Automation Account resource ID for integration.
// --------------------------------------------------------------------------------------

@description('The Azure region for this regional layer')
param location string

@description('The name of the Application Gateway')
param appGatewayName string

@description('The subnet resource ID for the Application Gateway')
param subnetId string

@description('The public IP resource ID for the Application Gateway')
param publicIpId string

@secure()
@description('The Key Vault secret ID for the SSL certificate')
param sslCertSecretId string

@description('The number of CELLs (stamps) in this region')
param cellCount int

@description('The FQDNs for each CELL backend in this region')
param cellBackendFqdns array

@description('Tags to apply to all resources')
param tags object = {}

@description('Health probe path for Application Gateway')
param healthProbePath string = '/health'

@description('The name of the Automation Account for this region')
param automationAccountName string = '${appGatewayName}-automation'

@description('Enable HTTPS listener for Application Gateway (set false for lab/smoke to use HTTP)')
param enableHttps bool = true

@description('Enable creation of a regional Automation Account (disabled in smoke)')
param enableAutomation bool = false

// Derived settings for HTTP/HTTPS toggling
var frontendPortName = enableHttps ? 'httpsPort' : 'httpPort'
var backendPort = enableHttps ? 443 : 80
var backendProtocol = enableHttps ? 'Https' : 'Http'
var probeProtocol = enableHttps ? 'Https' : 'Http'
var listenerName = enableHttps ? 'httpsListener' : 'httpListener'

// Generate backend pools, http settings, and probes for each CELL
var backendPools = [
  for i in range(0, cellCount): {
    name: 'cell${i + 1}-backend'
    properties: {
      backendAddresses: [
        {
          fqdn: cellBackendFqdns[i]
        }
      ]
    }
  }
]

var backendHttpSettings = [
  for i in range(0, cellCount): {
    name: 'cell${i + 1}-http-settings'
    properties: {
      port: backendPort
      protocol: backendProtocol
      probe: {
        id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'cell${i + 1}-probe')
      }
      pickHostNameFromBackendAddress: true
      requestTimeout: 30
    }
  }
]

var probes = [
  for i in range(0, cellCount): {
    name: 'cell${i + 1}-probe'
    properties: {
  protocol: probeProtocol
      host: cellBackendFqdns[i]
      path: healthProbePath
      interval: 30
      timeout: 30
      unhealthyThreshold: 3
      match: {
        statusCodes: ['200-399']
      }
    }
  }
]

// Application Gateway resource
// Note: Using a stable API version to align with current Bicep type definitions.
resource appGateway 'Microsoft.Network/applicationGateways@2022-09-01' = {
  name: appGatewayName
  location: location
  zones: ['1', '2'] // Deploy Application Gateway across at least two zones
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIp'
        properties: {
          publicIPAddress: {
            id: publicIpId
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: frontendPortName
        properties: {
          port: backendPort
        }
      }
    ]
    sslCertificates: enableHttps ? [
      {
        name: 'gatewayCert'
        properties: {
          keyVaultSecretId: sslCertSecretId
        }
      }
    ] : []
    httpListeners: concat(
      enableHttps ? [
        {
          name: 'httpsListener'
          properties: {
            frontendIPConfiguration: {
              id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIp')
            }
            frontendPort: {
              id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, frontendPortName)
            }
            protocol: 'Https'
            sslCertificate: {
              id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGatewayName, 'gatewayCert')
            }
          }
        }
      ] : [],
      !enableHttps ? [
        {
          name: 'httpListener'
          properties: {
            frontendIPConfiguration: {
              id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIp')
            }
            frontendPort: {
              id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, frontendPortName)
            }
            protocol: 'Http'
          }
        }
      ] : []
    )
    backendAddressPools: backendPools
    backendHttpSettingsCollection: backendHttpSettings
    probes: probes
    urlPathMaps: [
      {
        name: 'cellPathMap'
        properties: {
          defaultBackendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, backendPools[0].name)
          }
          defaultBackendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, backendHttpSettings[0].name)
          }
          pathRules: [
            for i in range(0, cellCount): {
              name: 'cell${i + 1}-path'
              properties: {
                paths: ['/cell${i + 1}/*']
                backendAddressPool: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, backendPools[i].name)
                }
                backendHttpSettings: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, backendHttpSettings[i].name)
                }
              }
            }
          ]
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'cellRoutingRule'
        properties: {
          ruleType: 'PathBasedRouting'
          // Priority is required starting from api-version 2021-08-01
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, listenerName)
          }
          urlPathMap: {
            id: resourceId('Microsoft.Network/applicationGateways/urlPathMaps', appGatewayName, 'cellPathMap')
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
    }
  }
  tags: tags
}

// Azure Automation Account for regional automation and runbooks
resource automationAccount 'Microsoft.Automation/automationAccounts@2020-01-13-preview' = if (enableAutomation) {
  name: automationAccountName
  location: location
  // Minimal properties to satisfy API; using preview types can vary, so keep lean for smoke
  properties: {}
  tags: tags
}

// Reference the existing Public IP by name and scope
resource publicIp 'Microsoft.Network/publicIPAddresses@2022-05-01' existing = {
  name: last(split(publicIpId, '/'))
  scope: resourceGroup()
}

// Output the regional public IP address for use in Traffic Manager endpoints
output regionalEndpointIpAddress string = publicIp.properties.ipAddress

// Output the Automation Account resource ID for integration or runbook assignment
output automationAccountId string = enableAutomation ? automationAccount.id : ''

// Comments:
// - Each CELL gets its own backend pool, HTTP settings, and health probe.
// - Path-based routing directs /cell1/* to CELL 1, /cell2/* to CELL 2, etc.
// - WAF is enabled for security.
// - SSL termination is handled at the gateway using a Key Vault certificate.
// - Regional Automation Account enables operational runbooks and automation.
// - All major parameters are exposed for flexibility.
