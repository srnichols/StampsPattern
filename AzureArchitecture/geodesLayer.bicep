// --------------------------------------------------------------------------------------
// Module: geodesLayer
// Purpose: Provisions API Management (APIM) and the Global Control Plane Cosmos DB account.
//          The global Cosmos DB is used for routing/lookup data and is replicated across all geos.
// --------------------------------------------------------------------------------------

@description('Azure region for the Geode (e.g., East US, West Europe)')
param location string = 'East US'

@description('Name of the API Management instance')
param apimName string = 'myDemoAPIM-eastus'

@description('APIM Publisher Email')
param apimPublisherEmail string

@description('APIM Publisher Name')
param apimPublisherName string

// Deploy API Management instance for the geode.
resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: apimName
  location: location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    // ...other properties...
  }
}

// --------------------------------------------------------------------------------------
// Global Control Plane Cosmos DB with Multi-Region Write Resilience
// This resource enables multi-region write and failover across all GEOs/regions.
// --------------------------------------------------------------------------------------

@description('Name for the global control plane Cosmos DB account')
param globalControlCosmosDbName string

@description('Primary location for the global Cosmos DB')
param primaryLocation string

@description('Additional locations for geo-replication (array of objects with locationName, failoverPriority)')
param additionalLocations array

@description('Tags for resources')
param tags object = {}

// Flatten the list of Cosmos DB locations
var additionalCosmosDbLocations = [for loc in additionalLocations: {
  locationName: loc.locationName
  failoverPriority: loc.failoverPriority
  isZoneRedundant: true
}]

var cosmosDbLocations = concat(
  [
    {
      locationName: primaryLocation
      failoverPriority: 0
      isZoneRedundant: true
    }
  ],
  additionalCosmosDbLocations
)

resource globalControlCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: globalControlCosmosDbName
  location: primaryLocation
  kind: 'GlobalDocumentDB'
  tags: tags
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: cosmosDbLocations
    enableMultipleWriteLocations: true
    databaseAccountOfferType: 'Standard'
  }
}
