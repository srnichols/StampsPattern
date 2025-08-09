@description('Location for resources')
param location string = resourceGroup().location

@description('Cosmos DB account name (must be globally unique)')
param cosmosAccountName string

// Reserved for future use: Container Apps resources

var tags = {
  'azd-env-name': deployment().name
}

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
        isZoneRedundant: true
      }
    ]
    publicNetworkAccess: 'Enabled'
    enableFreeTier: false
    capabilities: [
      {
        name: 'EnableNoSql'
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
