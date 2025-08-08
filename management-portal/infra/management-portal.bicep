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

@batchSize(1)
resource containers 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = [
  for c in [ 'tenants', 'cells', 'operations' ]: {
    parent: db
    name: c
    properties: {
      resource: {
        id: c
        partitionKey: {
          paths: [ '/pk' ]
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
]

// Note: Container Apps environment and apps to be added later
