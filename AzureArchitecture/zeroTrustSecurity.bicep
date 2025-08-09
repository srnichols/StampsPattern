// --------------------------------------------------------------------------------------
// Zero-Trust Network Security for Stamps Pattern
// - Implements comprehensive network micro-segmentation
// - Provides identity-based access controls
// - Enables real-time threat detection and response
// --------------------------------------------------------------------------------------

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Zero-trust security name prefix')
param zeroTrustPrefix string = 'stamps-zero-trust'

@description('Environment name')
@allowed(['dev', 'test', 'staging', 'prod'])
param environment string = 'prod'

@description('Tags for resources')
param tags object = {}

@description('Virtual Network resource ID')
param virtualNetworkId string

@description('Key Vault resource ID for certificate storage')
param keyVaultId string

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

// ============ NETWORK SECURITY COMPONENTS ============

// Network Security Group for Zero-Trust Rules
resource zeroTrustNSG 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${zeroTrustPrefix}-nsg-${environment}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      // Deny all inbound by default
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'Deny all inbound traffic by default'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
      // Allow HTTPS from Application Gateway only
      {
        name: 'AllowHTTPSFromAppGW'
        properties: {
          description: 'Allow HTTPS traffic from Application Gateway subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '10.0.1.0/24'
          destinationAddressPrefix: '10.0.2.0/24'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
  // Allow internal communication within workload subnet(s)
      {
        name: 'AllowInternalComm'
        properties: {
          description: 'Allow internal communication within workload subnet(s)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['80', '443']
          sourceAddressPrefix: '10.0.2.0/24'
          destinationAddressPrefix: '10.0.2.0/24'
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
        }
      }
      // Deny all outbound except specific destinations
      {
        name: 'DenyAllOutbound'
        properties: {
          description: 'Deny all outbound traffic by default'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Outbound'
        }
      }
      // Allow outbound to Azure services
      {
        name: 'AllowAzureServices'
        properties: {
          description: 'Allow outbound to Azure services'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
    ]
  }
}

// DDoS Protection Plan
resource ddosProtectionPlan 'Microsoft.Network/ddosProtectionPlans@2023-09-01' = {
  name: '${zeroTrustPrefix}-ddos-${environment}'
  location: location
  tags: tags
  properties: {}
}

// ============ IDENTITY-BASED ACCESS CONTROL ============

// Managed Identity for Zero-Trust Operations
resource zeroTrustIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${zeroTrustPrefix}-identity-${environment}'
  location: location
  tags: tags
}

// Key Vault Access Policy for Zero-Trust Identity
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  name: 'add'
  parent: keyVault
  properties: {
    accessPolicies: [
      {
        tenantId: tenant().tenantId
        objectId: zeroTrustIdentity.properties.principalId
        permissions: {
          secrets: ['get', 'list']
          certificates: ['get', 'list']
          keys: ['get', 'list', 'decrypt', 'encrypt']
        }
      }
    ]
  }
}

// Reference to existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: last(split(keyVaultId, '/'))
}

// ============ ADVANCED THREAT PROTECTION ============

// Network Watcher for Flow Logs
resource networkWatcher 'Microsoft.Network/networkWatchers@2023-09-01' = {
  name: '${zeroTrustPrefix}-netwatcher-${environment}'
  location: location
  tags: tags
  properties: {}
}

// Storage Account for Flow Logs
resource flowLogsStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${replace(zeroTrustPrefix, '-', '')}flowlogs${environment}'
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// NSG Flow Logs
resource nsgFlowLogs 'Microsoft.Network/networkWatchers/flowLogs@2023-09-01' = {
  parent: networkWatcher
  name: '${zeroTrustPrefix}-flowlogs-${environment}'
  location: location
  tags: tags
  properties: {
    targetResourceId: zeroTrustNSG.id
    storageId: flowLogsStorage.id
    enabled: true
    retentionPolicy: {
      days: 90
      enabled: true
    }
    format: {
      type: 'JSON'
      version: 2
    }
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: {
        enabled: true
        workspaceId: logAnalyticsWorkspace.properties.customerId
        workspaceRegion: location
        workspaceResourceId: logAnalyticsWorkspaceId
        trafficAnalyticsInterval: 10
      }
    }
  }
}

// Reference to existing Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: last(split(logAnalyticsWorkspaceId, '/'))
}

// ============ NETWORK MICRO-SEGMENTATION ============

// Azure Firewall for Advanced Filtering
resource azureFirewall 'Microsoft.Network/azureFirewalls@2023-09-01' = {
  name: '${zeroTrustPrefix}-firewall-${environment}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Premium'
    }
    threatIntelMode: 'Alert'
    additionalProperties: {
      'Network.DNS.EnableProxy': 'true'
      'Network.FTP.AllowActiveFTP': 'false'
    }
    ipConfigurations: [
      {
        name: 'firewall-ip-config'
        properties: {
          subnet: {
            id: '${virtualNetworkId}/subnets/AzureFirewallSubnet'
          }
          publicIPAddress: {
            id: firewallPublicIP.id
          }
        }
      }
    ]
    networkRuleCollections: [
      {
        name: 'AllowAzureServices'
        properties: {
          priority: 100
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'AllowKeyVaultAccess'
              description: 'Allow access to Key Vault'
              protocols: ['TCP']
              sourceAddresses: ['10.0.2.0/24']
              destinationAddresses: ['*']
              destinationPorts: ['443']
              destinationFqdns: ['*.${az.environment().suffixes.keyvaultDns}']
            }
            {
              name: 'AllowSQLAccess'
              description: 'Allow access to SQL Database'
              protocols: ['TCP']
              sourceAddresses: ['10.0.2.0/24']
              destinationAddresses: ['*']
              destinationPorts: ['1433']
              destinationFqdns: ['*.${az.environment().suffixes.sqlServerHostname}']
            }
          ]
        }
      }
    ]
    applicationRuleCollections: [
      {
        name: 'AllowSpecificDomains'
        properties: {
          priority: 200
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'AllowMicrosoftServices'
              description: 'Allow Microsoft services'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              sourceAddresses: ['10.0.2.0/24']
              targetFqdns: [
                '*.microsoft.com'
                '*.azure.com'
                '*.windows.net'
                '*.microsoftonline.com'
              ]
            }
          ]
        }
      }
    ]
  }
}

// Public IP for Azure Firewall
resource firewallPublicIP 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${zeroTrustPrefix}-firewall-pip-${environment}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${zeroTrustPrefix}-firewall-${environment}'
    }
    ddosSettings: {
      ddosProtectionPlan: {
        id: ddosProtectionPlan.id
      }
      protectionMode: 'VirtualNetworkInherited'
    }
  }
}

// ============ SECURITY MONITORING AND ANALYTICS ============

// Security Monitoring Workbook
resource zeroTrustSecurityWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('zero-trust-security-workbook', resourceGroup().id)
  location: location
  kind: 'shared'
  tags: tags
  properties: {
    displayName: 'Stamps Pattern: Zero-Trust Security Monitoring'
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# 🛡️ Zero-Trust Security Monitoring\\n\\n**Comprehensive security insights with network micro-segmentation and threat detection.**"
      }
    },
    {
      "type": 12,
      "content": {
        "version": "NotebookGroup/1.0",
        "groupType": "editable",
        "items": [
          {
            "type": 3,
            "content": {
              "version": "KqlItem/1.0",
              "query": "AzureNetworkAnalytics_CL\\n| where TimeGenerated > ago(24h)\\n| where SubType_s == \\"FlowLog\\"\\n| extend SourceIP = SrcIP_s, DestIP = DestIP_s, DestPort = DestPort_d\\n| summarize FlowCount = count() by SourceIP, DestIP, DestPort\\n| top 20 by FlowCount desc",
              "size": 0,
              "title": "🌐 Network Flow Analysis",
              "queryType": 0,
              "visualization": "table"
            }
          },
          {
            "type": 3,
            "content": {
              "version": "KqlItem/1.0",
              "query": "AzureDiagnostics\\n| where Category == \\"AzureFirewallNetworkRule\\" or Category == \\"AzureFirewallApplicationRule\\"\\n| where action_s == \\"Deny\\"\\n| summarize DeniedConnections = count() by bin(TimeGenerated, 1h), Category\\n| render timechart",
              "size": 0,
              "title": "🚫 Firewall Blocked Connections",
              "queryType": 0,
              "visualization": "timechart"
            }
          }
        ]
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "SecurityEvent\\n| where TimeGenerated > ago(24h)\\n| where EventID in (4624, 4625, 4648, 4719)\\n| summarize SecurityEvents = count() by EventID, bin(TimeGenerated, 1h)\\n| render timechart",
        "size": 0,
        "title": "🔐 Security Events Timeline",
        "queryType": 0,
        "visualization": "timechart"
      }
    }
  ]
}
'''
    category: 'workbook'
    sourceId: logAnalyticsWorkspaceId
  }
}

// ============ CONDITIONAL ACCESS SIMULATION ============

// Logic App for Conditional Access Simulation
resource conditionalAccessLogicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: '${zeroTrustPrefix}-conditional-access-${environment}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${zeroTrustIdentity.id}': {}
    }
  }
  properties: {
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        logAnalyticsWorkspaceId: {
          type: 'string'
          defaultValue: logAnalyticsWorkspaceId
        }
      }
      triggers: {
        recurrence: {
          type: 'Recurrence'
          recurrence: {
            frequency: 'Hour'
            interval: 4
          }
        }
      }
      actions: {
        'Analyze-Access-Patterns': {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: 'https://api.loganalytics.io/v1/workspaces/${last(split(logAnalyticsWorkspaceId, '/'))}/query'
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              query: 'SigninLogs | where TimeGenerated > ago(4h) | where ResultType != 0 | summarize FailedAttempts = count() by UserPrincipalName, IPAddress, bin(TimeGenerated, 1h)'
            }
            authentication: {
              type: 'ManagedServiceIdentity'
              identity: zeroTrustIdentity.id
            }
          }
        }
        'Generate-Risk-Score': {
          type: 'Compose'
          inputs: {
            riskAssessment: {
              timestamp: '@utcNow()'
              analysisType: 'ConditionalAccessSimulation'
              riskFactors: '@body(\'Analyze-Access-Patterns\')'
            }
          }
          runAfter: {
            'Analyze-Access-Patterns': ['Succeeded']
          }
        }
      }
    }
  }
}

// ============ OUTPUTS ============

output zeroTrustNSGId string = zeroTrustNSG.id
output zeroTrustIdentityId string = zeroTrustIdentity.id
output azureFirewallId string = azureFirewall.id
output ddosProtectionPlanId string = ddosProtectionPlan.id
output flowLogsStorageId string = flowLogsStorage.id
output zeroTrustSecurityWorkbookId string = zeroTrustSecurityWorkbook.id
output conditionalAccessLogicAppId string = conditionalAccessLogicApp.id
output networkWatcherId string = networkWatcher.id
