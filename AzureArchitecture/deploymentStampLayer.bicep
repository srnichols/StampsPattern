// Cosmos DB account name for the CELL/Stamp
var cosmosDbStampName = '${location}cellcosmosdb${uniqueString(resourceGroup().id, salt)}'
// ...existing code...

@description('Azure region for the CELL/Stamp')
param location string

@description('Resource ID of the user-assigned managed identity for deployment scripts and automation')
param userAssignedIdentityId string

@description('Name for the SQL Server')
param sqlServerName string

@description('SQL admin username')
param sqlAdminUsername string

@secure()
@description('SQL admin password')
param sqlAdminPassword string

@description('Name for the SQL Database')
param sqlDbName string

@description('SQL Database SKU tier (e.g., Basic, Standard, GeneralPurpose)')
param sqlDatabaseSkuTier string = 'Standard'

@description('SQL Database SKU name (e.g., Basic, S0, S1)')
param sqlDatabaseSkuName string = 'S1'

@description('Name for the Storage Account')
param storageAccountName string

@description('Name for the Key Vault for this CELL/Stamp')
param keyVaultName string

@description('Optional salt to ensure unique resource names for repeated deployments (e.g., date, initials, or random chars)')
param salt string = ''

@description('Tags for resources')
param tags object = {}


// Remove invalid resource declarations and misplaced decorators
// If storageEncryptionKey and sqlEncryptionKey are needed, declare them with valid resource types and unique names, e.g.:
// resource storageEncryptionKey 'Microsoft.KeyVault/vaults/keys@2023-02-01' = { ... }
// resource sqlEncryptionKey 'Microsoft.KeyVault/vaults/keys@2023-02-01' = { ... }

@description('Name of the Azure Container Registry for this region')
param containerRegistryName string
@description('Enable Azure Container Registry for this CELL (disabled in smoke)')
param enableContainerRegistry bool = false

@description('Name of the Container App for this CELL')
param containerAppName string

@description('Name of the Container App Environment for this CELL')
param containerAppEnvironmentName string
@description('Enable deployment of Container App Environment for this CELL')
param enableContainerAppEnvironment bool = true

@description('Base domain for the CELL')
param baseDomain string

// The globalLogAnalyticsWorkspaceId parameter is required for diagnostics on cell-level resources (Cosmos DB, Application Gateway, SQL Server, etc.).
// The logAnalyticsCustomerId parameter (GUID) is required for Container App Environment integration.
// Both values are passed from main.bicep, which gets them from monitoringLayers[0] outputs.
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

@description('Enable a per-cell Traffic Manager profile (disabled in smoke; global TM is managed in global layer)')
param enableCellTrafficManager bool = false


// ---------------- Data HA/DR Optional Parameters (all optional, safe defaults) ----------------
// These apply to CELL-layer resources only. Global control plane data replication is configured
// in the global layer and is not affected by these parameters.

@description('Default storage SKU for CELL storage accounts')
@allowed([ 'Premium_ZRS', 'Standard_GZRS', 'Standard_RAGZRS', 'Standard_LRS' ])
param storageSkuName string = 'Premium_ZRS'

// Removed parameters:
// - enableStorageObjectReplication (unused)
// - storageReplicationDestinationId (unused)

@description('Additional Cosmos DB locations for this CELL (optional)')
param cosmosAdditionalLocations array = []

@description('Enable Cosmos DB multi-write across locations (Active/Active)')
param cosmosMultiWrite bool = false


// Removed: cosmosZoneRedundant (unused)


@description('Enable SQL Auto-failover Group to a partner server in another region')
param enableSqlFailoverGroup bool = false

@description('Resource ID of the partner SQL Server for Auto-failover Group')
param sqlSecondaryServerId string = ''

@description('Create the storage account in this deployment (set false to use an existing account)')
param createStorageAccount bool = true

@description('Diagnostics mode for this CELL. Use metricsOnly to minimize categories in constrained environments (smoke).')
@allowed(['metricsOnly','standard'])
param diagnosticsMode string = 'metricsOnly'

var diagMetricsOnly = diagnosticsMode == 'metricsOnly'


// Create a new Azure Container Registry for the region with security hardening
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = if (enableContainerRegistry) {
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
    // Policies omitted in smoke
    // Use Microsoft-managed encryption by default in smoke; CMK can be configured post-deployment
  }
  tags: tags
}

@description('Log Analytics Workspace customerId (GUID) for Container App Environment')
param logAnalyticsCustomerId string

@description('Log Analytics Workspace Key Vault name for Container App Environment')
param logAnalyticsWorkspaceKeyVaultName string

@description('Log Analytics Workspace shared key secret name for Container App Environment')
param logAnalyticsWorkspaceKeySecretName string


// Container App Environment for this CELL
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = if (enableContainerAppEnvironment) {
  name: containerAppEnvironmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: reference(resourceId('Microsoft.KeyVault/vaults/secrets', logAnalyticsWorkspaceKeyVaultName, logAnalyticsWorkspaceKeySecretName), '2023-02-01').secretValue
      }
    }

        

        
    zoneRedundant: false
  }
  tags: tags
}

// Front Door configuration is managed at the global layer. Omitted from CELL layer in smoke.

resource trafficManager 'Microsoft.Network/trafficManagerProfiles@2022-04-01' = if (enableCellTrafficManager) {
  name: 'tm-${location}-cell-${uniqueString(resourceGroup().id, salt)}'
  location: 'global'
  properties: {
    trafficRoutingMethod: 'Performance'
    dnsConfig: {
      relativeName: 'tm${uniqueString(resourceGroup().id)}'
      ttl: 30
    }
    monitorConfig: {
      protocol: 'HTTP'
      port: 80
      path: '/health'
    }
    endpoints: []
  }
}

// Compose Cosmos DB locations list (primary + any additional)
// Map additional locations to Cosmos location objects (ensure parameters avoid duplicates of primary)
var cosmosAdditionalLocationObjs = [for (loc, idx) in cosmosAdditionalLocations: {
  locationName: string(loc)
  failoverPriority: idx + 1
  isZoneRedundant: false
}]

var cosmosDbLocations = concat([
  {
    locationName: location
    failoverPriority: 0
    isZoneRedundant: false
  }
], cosmosAdditionalLocationObjs)

// Cosmos DB for CELL with zone redundancy and enhanced backup configuration (optional multi-region)
resource cellCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosDbStampName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: cosmosDbLocations
    enableMultipleWriteLocations: cosmosMultiWrite
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
    enableAutomaticFailover: length(cosmosAdditionalLocations) > 0
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
    publicNetworkAccess: 'Disabled' // Zero-trust: Always disable public access
  }
  tags: tags
}

// Diagnostic settings for Cosmos DB (top-level, correct scope)
resource cosmosDbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${cosmosDbStampName}-diagnostics'
  scope: cellCosmosDb
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: diagMetricsOnly ? [] : [
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

// Storage Account logic

resource storageAccountCreate 'Microsoft.Storage/storageAccounts@2022-09-01' = if (createStorageAccount) {
  name: storageAccountName
  location: location
  sku: {
    name: storageSkuName
  }
  kind: storageSkuName == 'Premium_ZRS' ? 'BlockBlobStorage' : 'StorageV2'
  properties: {
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
  }
  // ...existing code...
  // Object replication and lifecycle policy resources commented out due to invalid properties/type issues. Uncomment and fix if needed.
  // resource storageObjectReplication 'objectReplicationPolicies@2021-09-01' = if (storageSkuName != 'Premium_ZRS' && enableStorageObjectReplication && !empty(storageReplicationDestinationId)) {
  //   name: 'cell-replication'
  //   properties: {
  //     sourceAccount: storageAccountCreate.id
  //     destinationAccount: storageReplicationDestinationId
  //     rules: [
  //       {
  //         ruleId: 'rule-1'
  //         sourceContainer: 'appdata'
  //         destinationContainer: 'appdata'
  //         filters: {
  //           prefixMatch: []
  //         }
  //       }
  //     ]
  //   }
  // }
  // resource storageLifecyclePolicy 'managementPolicies@2022-09-01' = if (storageSkuName != 'Premium_ZRS') {
  //   name: 'default'
  //   properties: {
  //     policy: {
  //       rules: [
  //         {
  //           name: 'DefaultLifecycleRule'
  //           enabled: true
  //           type: 'Lifecycle'
  //           definition: {
  //             filters: {
  //               blobTypes: ['blockBlob']
  //             }
  //             actions: {
  //               baseBlob: {
  //                 tierToCool: {
  //                   daysAfterModificationGreaterThan: 30
  //                 }
  //                 delete: {
  //                   daysAfterModificationGreaterThan: 365
  //                 }
  //               }
  //               snapshot: {
  //                 delete: {
  //                   daysAfterCreationGreaterThan: 30
  //                 }
  //               }
  //               version: {
  //                 delete: {
  //                   daysAfterCreationGreaterThan: 30
  //                 }
  //               }
  //             }
  //           }
  //         }
  //       ]
  //     }
  //   }
  // }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: empty(salt) ? keyVaultName : '${keyVaultName}${salt}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: reference(userAssignedIdentityId, '2018-11-30', 'Full').principalId
        permissions: {
          secrets: ['get', 'list', 'set']
        }
      }
    ]
  }
  tags: tags
}


// Key Vault access policies (created separately to avoid circular dependencies)

// Separate access policy assignment for SQL Server managed identity, after SQL Server is created


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
          privateLinkServiceId: resourceId('Microsoft.Storage/storageAccounts', storageAccountName)
          groupIds: ['blob']
        }
      }
    ]
  }
  tags: tags
}

resource sqlAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
parent: keyVault
name: 'sqlAdminPassword'
properties: {
  value: sqlAdminPassword
}
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
  name: empty(salt) ? '${keyVaultName}-pe' : '${keyVaultName}${salt}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'keyvault-connection'
        properties: {
          privateLinkServiceId: resourceId('Microsoft.KeyVault/vaults', keyVaultResourceName)
          groupIds: ['vault']
        }
      }
    ]
  }
  tags: tags
}

// Private endpoint for Container Registry
resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (enableContainerRegistry && enablePrivateEndpoints && !empty(privateEndpointSubnetId)) {
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
    logs: diagMetricsOnly ? [] : [
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

// Diagnostic settings for Storage Account (top-level, correct scope)
// resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (createStorageAccount) {
//   name: '${storageAccountName}-diagnostics'
//   scope: storageAccountCreate
//   properties: {
//     workspaceId: globalLogAnalyticsWorkspaceId
//     metrics: [
//       {
//         category: 'AllMetrics'
//         enabled: true
//       }
//     ]
//   }
// }

// resource storageDiagnosticsExisting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!createStorageAccount) {
//   name: '${storageAccountName}-diagnostics'
//   scope: storageAccount
//   properties: {
//     workspaceId: globalLogAnalyticsWorkspaceId
//     metrics: [
//       {
//         category: 'AllMetrics'
//         enabled: true
//       }
//     ]
//   }
// }

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
    administratorLoginPassword: reference(resourceId('Microsoft.KeyVault/vaults/secrets', keyVaultResourceName, 'sqlAdminPassword'), '2023-02-01').secretValue
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
}
  // dependsOn removed as per linter suggestion

// SQL Server firewall rule is not created because public network access is disabled.
// If you enable public access, add a conditional firewall rule accordingly.

// SQL Database with backup configuration
resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-11-01-preview' = {
  parent: sqlServer
  name: sqlDbName
  location: location
  tags: tags
  sku: {
  name: sqlDatabaseSkuName
  tier: sqlDatabaseSkuTier
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
  // Some log categories vary by tier/region; for portability in smoke, emit metrics only.
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Optional: SQL Auto-failover Group to partner server
resource sqlFailoverGroup 'Microsoft.Sql/servers/failoverGroups@2021-11-01' = if (enableSqlFailoverGroup && !empty(sqlSecondaryServerId)) {
  name: 'fg-${sqlServerName}'
  parent: sqlServer
  properties: {
    partnerServers: [
      {
        id: sqlSecondaryServerId
      }
    ]
    databases: [ sqlDatabase.id ]
    readWriteEndpoint: {
      failoverPolicy: 'Automatic'
      failoverWithDataLossGracePeriodMinutes: 120
    }
    readOnlyEndpoint: {
      failoverPolicy: 'Enabled'
    }
  }
}


// Outputs (secure - no credential exposure)
// ACR outputs omitted in smoke
output keyVaultId string = resourceId('Microsoft.KeyVault/vaults', keyVaultResourceName)
output keyVaultUri string = reference(resourceId('Microsoft.KeyVault/vaults', keyVaultResourceName), '2023-02-01').properties.vaultUri
output sqlServerSystemAssignedPrincipalId string = sqlServer.identity.principalId
output storageAccountSystemAssignedPrincipalId string = createStorageAccount ? 'assigned' : 'not-assigned'
output cosmosDbId string = cellCosmosDb.id
output cosmosDbEndpoint string = cellCosmosDb.properties.documentEndpoint
output applicationGatewayId string = enableApplicationGateway && !empty(applicationGatewaySubnetId) ? applicationGateway.id : 'not-deployed'
output applicationGatewayPublicIPId string = enableApplicationGateway && !empty(applicationGatewaySubnetId) ? applicationGatewayPublicIP.id : 'not-deployed'
var keyVaultResourceName = empty(salt) ? keyVaultName : format('{0}{1}', keyVaultName, salt)
output storageEncryptionKeyId string = resourceId('Microsoft.KeyVault/vaults/keys', keyVaultResourceName, 'storage-encryption-key')
output sqlEncryptionKeyId string = resourceId('Microsoft.KeyVault/vaults/keys', keyVaultResourceName, 'sql-tde-encryption-key')
output containerAppEnvironmentId string = enableContainerAppEnvironment ? containerAppEnvironment.id : 'not-deployed'

