@description('Location for resources')
param location string = resourceGroup().location

@description('Cosmos DB account name (must be globally unique)')
param cosmosAccountName string

@description('Container Apps Environment name')
param containerAppsEnvironmentName string = 'cae-stamps-mgmt'

@description('Container Registry name (must be globally unique)')
param containerRegistryName string

@description('Log Analytics Workspace name')
param logAnalyticsWorkspaceName string = 'law-stamps-mgmt'

@description('Application Insights name')
param appInsightsName string = 'ai-stamps-mgmt'

@description('Common tags for resources')
param tags object = {}

@description('Azure Entra ID Client ID for authentication')
param azureClientId string = 'e691193e-4e25-4a72-9185-1ce411aa2fd8'

@description('Azure Entra ID Tenant ID for authentication')
param azureTenantId string = '16b3c013-d300-468d-ac64-7eda0820b6d3'

@description('Enable using Key Vault for secrets instead of inline/container-app secrets')
param useKeyVault bool = false

@description('Key Vault name to read secrets from when useKeyVault = true')
param keyVaultName string = ''

@description('Portal container image')
param portalImage string

@description('DAB container image')
param dabImage string

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: cosmosAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    publicNetworkAccess: 'Enabled'
    enableFreeTier: false
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
  tags: tags
}

resource db 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmos
  name: 'stamps-control-plane'
  properties: {
    resource: {
      id: 'stamps-control-plane'
    }
  }
}

// Tenants container: pk on /tenantId, composite index for domain+status
resource tenantsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: db
  name: 'tenants'
  properties: {
    resource: {
      id: 'tenants'
      partitionKey: {
        paths: [ '/tenantId' ]
        kind: 'Hash'
        version: 2
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        compositeIndexes: [
          [
            {
              path: '/domain'
              order: 'ascending'
            }
            {
              path: '/status'
              order: 'ascending'
            }
          ]
        ]
      }
      // Note: Unique keys are enforced per-partition. With pk = /tenantId, a unique key on /domain does not enforce global uniqueness.
      // Consider registering domains in the 'catalogs' container (type='domains', id=<domain>) to guarantee global uniqueness.
      uniqueKeyPolicy: {
        uniqueKeys: [
          {
            paths: [ '/domain' ]
          }
        ]
      }
    }
    options: {}
  }
}

// Cells container: pk on /cellId
resource cellsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: db
  name: 'cells'
  properties: {
    resource: {
      id: 'cells'
      partitionKey: {
        paths: [ '/cellId' ]
        kind: 'Hash'
        version: 2
      }
      indexingPolicy: {
        indexingMode: 'consistent'
      }
    }
    options: {}
  }
}

// Operations container: pk on /tenantId, default TTL ~60 days (5184000 seconds)
resource operationsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: db
  name: 'operations'
  properties: {
    resource: {
      id: 'operations'
      partitionKey: {
        paths: [ '/tenantId' ]
        kind: 'Hash'
        version: 2
      }
      indexingPolicy: {
        indexingMode: 'consistent'
      }
      defaultTtl: 5184000
    }
    options: {}
  }
}

// Catalogs container: pk on /type for simple lookups
resource catalogsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: db
  name: 'catalogs'
  properties: {
    resource: {
      id: 'catalogs'
      partitionKey: {
        paths: [ '/type' ]
        kind: 'Hash'
        version: 2
      }
      indexingPolicy: {
        indexingMode: 'consistent'
      }
    }
    options: {}
  }
}

// Note: Container Apps environment and apps to be added later

// Log Analytics Workspace for monitoring
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
  tags: tags
}

// Application Insights for application monitoring
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
  tags: tags
}

// Container Registry for storing container images
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
  tags: tags
}

// Container Apps Environment with Dapr enabled
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppsEnvironmentName
  location: location
  properties: {
    daprAIInstrumentationKey: appInsights.properties.InstrumentationKey
    daprAIConnectionString: appInsights.properties.ConnectionString
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
  tags: tags
}

// User-assigned managed identity for container apps
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-stamps-mgmt'
  location: location
  tags: tags
}

// Role assignment for managed identity to access Container Registry
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, managedIdentity.id, 'AcrPull')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment for managed identity to access Cosmos DB
resource cosmosContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cosmos.id, managedIdentity.id, 'CosmosDBDataContributor')
  scope: cosmos
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Cosmos DB Contributor
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Data API Builder Container App
resource dabContainerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-stamps-dab'
  location: location
  dependsOn: [
    acrPullRoleAssignment
    cosmosContributorRoleAssignment
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      dapr: {
        enabled: true
        appId: 'dab'
        appProtocol: 'http'
        appPort: 80
        enableApiLogging: true
      }
      ingress: {
        external: true
        targetPort: 80
        allowInsecure: false
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
          allowedHeaders: ['*']
          allowCredentials: false
        }
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
  registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: managedIdentity.id
        }
      ]
      secrets: [
        {
          name: 'cosmos-connection-string'
          value: cosmos.listConnectionStrings().connectionStrings[0].connectionString
        }
        {
          name: 'appinsights-connection-string'
          value: appInsights.properties.ConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          // Use the built image for DAB which expects to be exposed on port 80
          image: dabImage
          name: 'dab'
          // Let the container use its default entrypoint instead of overriding
          // command: [ 'dab', 'start', '--host', '0.0.0.0', '--config', '/App/dab-config.json' ]
          env: [
            {
              name: 'COSMOS_CONNECTION_STRING'
              secretRef: 'cosmos-connection-string'
            }
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              secretRef: 'appinsights-connection-string'
            }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '30'
              }
            }
          }
        ]
      }
    }
  }
  tags: union(tags, {
    'azd-service-name': 'dab'
  })
}

// Management Portal Container App
resource portalContainerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-stamps-portal'
  location: location
  dependsOn: [
    acrPullRoleAssignment
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      dapr: {
        enabled: true
        appId: 'portal'
        appProtocol: 'http'
        appPort: 8080
        enableApiLogging: true
      }
      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: false
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
          allowedHeaders: ['*']
          allowCredentials: false
        }
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: managedIdentity.id
        }
      ]
      // Secrets currently set as container app secrets. If you prefer Key Vault
      // integration, set `useKeyVault` to true and provide `keyVaultName`.
      // Then create the Key Vault secrets (AzureAd-ClientId, AzureAd-TenantId,
      // appinsights-connection-string, dab-graphql-url) in the Key Vault and
      // grant the portal managed identity access to read secrets. Example manual
      // steps are in the repository docs. For now we keep container app secrets
      // for quick deployments.
      secrets: [
        {
          name: 'dab-graphql-url'
          value: 'https://${dabContainerApp.properties.configuration.ingress.fqdn}/graphql'
        }
        {
          name: 'appinsights-connection-string'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'azure-ad-client-id'
          value: azureClientId
        }
        {
          name: 'azure-ad-tenant-id'
          value: azureTenantId
        }
      ]
    }
    template: {
      containers: [
        {
          image: portalImage
          name: 'portal'
          env: [
            {
              name: 'DAB_GRAPHQL_URL'
              secretRef: 'dab-graphql-url'
            }
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              secretRef: 'appinsights-connection-string'
            }
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://+:8080'
            }
            {
              name: 'AzureAd__ClientId'
              secretRef: 'azure-ad-client-id'
            }
            {
              name: 'AzureAd__TenantId'
              secretRef: 'azure-ad-tenant-id'
            }
            {
              name: 'AzureAd__Instance'
              value: environment().authentication.loginEndpoint
            }
            {
              name: 'AzureAd__CallbackPath'
              value: '/signin-oidc'
            }
            {
              name: 'AzureAd__SignedOutCallbackPath'
              value: '/signout-callback-oidc'
            }
            {
              name: 'RUNNING_IN_PRODUCTION'
              value: 'true'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 5
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
  tags: union(tags, {
    'azd-service-name': 'portal'
  })
}

// Outputs
output cosmosEndpoint string = cosmos.properties.documentEndpoint
output portalUrl string = 'https://${portalContainerApp.properties.configuration.ingress.fqdn}'
output dabUrl string = 'https://${dabContainerApp.properties.configuration.ingress.fqdn}'
output containerRegistryName string = containerRegistry.name
output containerRegistryLoginServer string = containerRegistry.properties.loginServer
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
