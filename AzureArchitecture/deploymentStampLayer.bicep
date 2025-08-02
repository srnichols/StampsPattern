// --------------------------------------------------------------------------------------
// CELL Layer Module
// - Deploys isolated application/data resources for a single CELL
// - Intended to be deployed multiple times per region for full isolation
// - Receives dependencies from regional and global layers
// - Network isolation and diagnostic settings are included per CELL
// - Implements host-based (subdomain) routing for tenants via Azure Front Door
// --------------------------------------------------------------------------------------

@description('Azure region for the CELL/Stamp')
param location string

@description('Name for the SQL Server')
param sqlServerName string

@description('SQL admin username')
param sqlAdminUsername string

@secure()
@description('SQL admin password')
param sqlAdminPassword string

@description('Name for the SQL Database')
param sqlDbName string

@description('Name for the Storage Account')
param storageAccountName string

@description('Name for the Key Vault for this CELL/Stamp')
param keyVaultName string

@description('Name for the Cosmos DB account for this CELL/Stamp')
param cosmosDbStampName string

@description('Tags for resources')
param tags object = {}

@description('Name of the Azure Container Registry for this region')
param containerRegistryName string

@description('Name of the Container App for this CELL')
param containerAppName string

@description('Base domain for the CELL')
param baseDomain string

@description('The resource ID of the central Log Analytics Workspace for diagnostics.')
param globalLogAnalyticsWorkspaceId string

@description('Subnet resource ID for private endpoints')
param privateEndpointSubnetId string = ''

@description('Enable private endpoints for enhanced security')
param enablePrivateEndpoints bool = false

@description('Enable Application Gateway WAF for advanced threat protection')
param enableApplicationGateway bool = false

@description('Application Gateway subnet resource ID')
param applicationGatewaySubnetId string = ''

// Create a new Azure Container Registry for the region with security hardening
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // Security hardening
    adminUserEnabled: false
    dataEndpointEnabled: false
    publicNetworkAccess: 'Enabled' // Can be set to 'Disabled' for private access only
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      quarantinePolicy: {
        status: 'enabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'enabled'
      }
      retentionPolicy: {
        days: 7
        status: 'enabled'
      }
    }
    encryption: {
      status: 'enabled'
    }
  }
  tags: tags
}

// Front Door backend pools
var frontDoorBackendPools = [
  {
    name: '${containerAppName}-backend'
    backends: [
      {
        address: '${containerAppName}.${baseDomain}'
        httpPort: 80
        httpsPort: 443
      }
    ]
    healthProbeSettings: {
      protocol: 'Https'
      path: '/health'
      intervalInSeconds: 30
    }
  }
]

// Front Door resource definition
resource frontDoor 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: 'myFrontDoor'
  location: 'global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

// Prepare Traffic Manager endpoints using a variable (move for-expression here)
var trafficManagerEndpoints = [
  for cell in frontDoorBackendPools: {
    name: cell.name
    type: 'ExternalEndpoints'
    properties: {
      target: cell.backends[0].address
      endpointStatus: 'Enabled'
    }
  }
]

// Traffic Manager resource definition
resource trafficManager 'Microsoft.Network/trafficManagerProfiles@2022-04-01' = {
  name: 'myTrafficManager'
  location: 'global'
  properties: {
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
    endpoints: trafficManagerEndpoints
  }
}

// Cosmos DB for CELL with zone redundancy and enhanced backup configuration
resource cellCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosDbStampName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: true // Enable zone redundancy for CELL Cosmos DB
      }
    ]
    enableMultipleWriteLocations: false
    databaseAccountOfferType: 'Standard'
    // Enhanced backup configuration
    backupPolicy: {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous7Days'
      }
    }
    // Security and compliance features
    enableFreeTier: false
    enableAnalyticalStorage: false
    enableAutomaticFailover: true
    disableKeyBasedMetadataWriteAccess: true
    networkAclBypass: 'AzureServices'
    networkAclBypassResourceIds: []
    // Network restrictions
    isVirtualNetworkFilterEnabled: enablePrivateEndpoints
    virtualNetworkRules: []
    ipRules: []
    // Advanced security
    enableCassandraConnector: false
    minimalTlsVersion: 'Tls12'
    publicNetworkAccess: enablePrivateEndpoints ? 'Disabled' : 'Enabled'
  }
  tags: tags
}

// Diagnostic settings for Cosmos DB
resource cosmosDbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${cosmosDbStampName}-diagnostics'
  scope: cellCosmosDb
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      {
        category: 'DataPlaneRequests'
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

// Storage Account for CELL with Premium_ZRS SKU for zone redundancy and security hardening
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Premium_ZRS' // Use zone-redundant storage
  }
  kind: 'StorageV2'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // Security hardening
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
    }
    // Encryption settings (initially with service-managed keys, can be updated to customer-managed post-deployment)
    encryption: {
      requireInfrastructureEncryption: true
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
  tags: tags
}

// Storage lifecycle management policy for cost optimization
resource storageLifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2022-09-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          name: 'DefaultLifecycleRule'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: ['blockBlob']
            }
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: 30
                }
                tierToArchive: {
                  daysAfterModificationGreaterThan: 90
                }
                delete: {
                  daysAfterModificationGreaterThan: 365
                }
              }
              snapshot: {
                delete: {
                  daysAfterCreationGreaterThan: 30
                }
              }
              version: {
                delete: {
                  daysAfterCreationGreaterThan: 30
                }
              }
            }
          }
        }
      ]
    }
  }
}

// Key Vault for CELL with security hardening
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    // Security hardening
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled' // Can be set to 'Disabled' for private access
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
    accessPolicies: []  // Start with empty access policies to avoid circular dependencies
  }
  tags: tags
}

// Key Vault access policies (created separately to avoid circular dependencies)
resource keyVaultAccessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2023-02-01' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      // Grant access to SQL Server managed identity
      {
        objectId: sqlServer.identity.principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: ['get']
          keys: ['get', 'wrapKey', 'unwrapKey']
        }
      }
      // Grant access to Storage Account managed identity
      {
        objectId: storageAccount.identity.principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: ['get']
          keys: ['get', 'wrapKey', 'unwrapKey']
        }
      }
      // Grant access to Container Registry managed identity
      {
        objectId: containerRegistry.identity.principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: ['get']
        }
      }
    ]
  }
}

// Customer-managed encryption key for Storage Account
resource storageEncryptionKey 'Microsoft.KeyVault/vaults/keys@2023-02-01' = {
  parent: keyVault
  name: 'storage-encryption-key'
  properties: {
    kty: 'RSA'
    keySize: 2048
    keyOps: [
      'encrypt'
      'decrypt'
      'wrapKey'
      'unwrapKey'
    ]
  }
}

// Customer-managed encryption key for SQL Server TDE
resource sqlEncryptionKey 'Microsoft.KeyVault/vaults/keys@2023-02-01' = {
  parent: keyVault
  name: 'sql-tde-encryption-key'
  properties: {
    kty: 'RSA'
    keySize: 2048
    keyOps: [
      'encrypt'
      'decrypt'
      'wrapKey'
      'unwrapKey'
    ]
  }
}

// Diagnostic settings for Key Vault
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVaultName}-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
      {
        category: 'AzurePolicyEvaluationDetails'
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

// Private Endpoints for enhanced network security (conditional deployment)

// Private endpoint for Storage Account
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (enablePrivateEndpoints && !empty(privateEndpointSubnetId)) {
  name: '${storageAccountName}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storageAccountName}-psc'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['blob']
        }
      }
    ]
  }
  tags: tags
}

// Private endpoint for SQL Server
resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (enablePrivateEndpoints && !empty(privateEndpointSubnetId)) {
  name: '${sqlServerName}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${sqlServerName}-psc'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: ['sqlServer']
        }
      }
    ]
  }
  tags: tags
}

// Private endpoint for Key Vault
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (enablePrivateEndpoints && !empty(privateEndpointSubnetId)) {
  name: '${keyVaultName}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-psc'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: ['vault']
        }
      }
    ]
  }
  tags: tags
}

// Private endpoint for Container Registry
resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (enablePrivateEndpoints && !empty(privateEndpointSubnetId)) {
  name: '${containerRegistryName}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${containerRegistryName}-psc'
        properties: {
          privateLinkServiceId: containerRegistry.id
          groupIds: ['registry']
        }
      }
    ]
  }
  tags: tags
}

// Private endpoint for Cosmos DB
resource cosmosDbPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (enablePrivateEndpoints && !empty(privateEndpointSubnetId)) {
  name: '${cosmosDbStampName}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${cosmosDbStampName}-psc'
        properties: {
          privateLinkServiceId: cellCosmosDb.id
          groupIds: ['Sql']
        }
      }
    ]
  }
  tags: tags
}

// Application Gateway with WAF v2 for advanced threat protection
resource applicationGatewayPublicIP 'Microsoft.Network/publicIPAddresses@2023-04-01' = if (enableApplicationGateway && !empty(applicationGatewaySubnetId)) {
  name: '${containerAppName}-agw-pip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  tags: tags
}

resource applicationGateway 'Microsoft.Network/applicationGateways@2023-04-01' = if (enableApplicationGateway && !empty(applicationGatewaySubnetId)) {
  name: '${containerAppName}-agw'
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: applicationGatewaySubnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: {
            id: applicationGatewayPublicIP.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
      {
        name: 'port_443'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'appServiceBackendPool'
        properties: {
          backendAddresses: [
            {
              fqdn: '${containerAppName}.${baseDomain}'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'appServiceBackendHttpSettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          probeEnabled: true
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', '${containerAppName}-agw', 'healthProbe')
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'appServiceHttpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', '${containerAppName}-agw', 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', '${containerAppName}-agw', 'port_80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'appServiceRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', '${containerAppName}-agw', 'appServiceHttpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', '${containerAppName}-agw', 'appServiceBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', '${containerAppName}-agw', 'appServiceBackendHttpSettings')
          }
        }
      }
    ]
    probes: [
      {
        name: 'healthProbe'
        properties: {
          protocol: 'Https'
          host: '${containerAppName}.${baseDomain}'
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
          minServers: 0
          match: {
            statusCodes: ['200-399']
          }
        }
      }
    ]
  }
  tags: tags
}

// Diagnostic settings for Application Gateway
resource applicationGatewayDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableApplicationGateway && !empty(applicationGatewaySubnetId)) {
  name: '${containerAppName}-agw-diagnostics'
  scope: applicationGateway
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayFirewallLog'
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

// Diagnostic settings for Storage Account
resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${storageAccountName}-diagnostics'
  scope: storageAccount
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
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

// SQL Server for CELL with security hardening
resource sqlServer 'Microsoft.Sql/servers@2022-11-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    // Security hardening
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
}

// SQL Server firewall rule to allow Azure services
resource sqlFirewallRule 'Microsoft.Sql/servers/firewallRules@2022-11-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// SQL Database with backup configuration
resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-11-01-preview' = {
  parent: sqlServer
  name: sqlDbName
  location: location
  tags: tags
  sku: {
    name: 'S1'
    tier: 'Standard'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    requestedBackupStorageRedundancy: 'GeoZone'
  }
}

// SQL Database long-term retention policy for backup optimization
resource sqlDatabaseLongTermRetentionPolicy 'Microsoft.Sql/servers/databases/backupLongTermRetentionPolicies@2022-11-01-preview' = {
  parent: sqlDatabase
  name: 'default'
  properties: {
    weeklyRetention: 'P12W'    // 12 weeks
    monthlyRetention: 'P12M'   // 12 months  
    yearlyRetention: 'P5Y'     // 5 years
    weekOfYear: 1              // First week of year for yearly backup
  }
}

// Diagnostic settings for SQL Server
resource sqlServerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${sqlServerName}-diagnostics'
  scope: sqlServer
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
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

// Outputs (secure - no credential exposure)
output acrLoginServer string = containerRegistry.properties.loginServer
output acrId string = containerRegistry.id
output acrSystemAssignedPrincipalId string = containerRegistry.identity.principalId
output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
output sqlServerSystemAssignedPrincipalId string = sqlServer.identity.principalId
output storageAccountSystemAssignedPrincipalId string = storageAccount.identity.principalId
output cosmosDbId string = cellCosmosDb.id
output cosmosDbEndpoint string = cellCosmosDb.properties.documentEndpoint
output applicationGatewayId string = enableApplicationGateway && !empty(applicationGatewaySubnetId) ? applicationGateway.id : 'not-deployed'
output applicationGatewayPublicIPId string = enableApplicationGateway && !empty(applicationGatewaySubnetId) ? applicationGatewayPublicIP.id : 'not-deployed'
output storageEncryptionKeyId string = storageEncryptionKey.properties.keyUriWithVersion
output sqlEncryptionKeyId string = sqlEncryptionKey.properties.keyUriWithVersion
