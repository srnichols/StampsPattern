// --------------------------------------------------------------------------------------
// Module: geodesLayer
// Purpose: Provisions Enterprise-grade API Management (APIM) and the Global Control Plane Cosmos DB account.
//          APIM provides multi-region API gateway with tenant isolation, rate limiting, and developer portals.
//          The global Cosmos DB is used for routing/lookup data and is replicated across all geos.
// --------------------------------------------------------------------------------------

@description('Azure region for the primary Geode (e.g., eastus, westeurope)')
param location string

@description('Name of the API Management instance')
param apimName string

@description('APIM Publisher Email')
param apimPublisherEmail string

@description('APIM Publisher Name')
param apimPublisherName string

@description('Additional regions for APIM multi-region deployment')
param apimAdditionalRegions array = []

@description('Custom domain for APIM (e.g., api.contoso.com)')
param customDomain string = ''

@description('Tags for resource management')
param tags object = {}

@description('The resource ID of the central Log Analytics Workspace for diagnostics')
param globalLogAnalyticsWorkspaceId string

// Deploy Enterprise Premium APIM instance for the geode with multi-region support
resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: 'Premium'    // Premium required for multi-region, VNet integration, and enterprise features
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    virtualNetworkType: 'None'
    additionalLocations: [for region in apimAdditionalRegions: {
      location: region.location
      sku: {
        name: 'Premium'
        capacity: region.capacity ?? 1
      }
      zones: region.zones ?? []
    }]
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
    }
    apiVersionConstraint: {
      minApiVersion: '2021-08-01'
    }
  }
  tags: tags
}

// Configure custom domain if provided
resource apimCustomDomain 'Microsoft.ApiManagement/service/gateways@2023-05-01-preview' = if (!empty(customDomain)) {
  name: 'gateway-custom'
  parent: apim
  properties: {
    description: 'Custom domain gateway for multi-tenant API access'
    locationData: {
      name: 'Custom Domain'
      countryOrRegion: 'Global'
    }
  }
}

// Enterprise API Policies for tenant isolation and security
resource apimGlobalPolicy 'Microsoft.ApiManagement/service/policies@2023-05-01-preview' = {
  name: 'policy'
  parent: apim
  properties: {
    value: '''
    <policies>
      <inbound>
        <!-- Global security headers -->
        <set-header name="X-Frame-Options" exists-action="override">
          <value>DENY</value>
        </set-header>
        <set-header name="X-Content-Type-Options" exists-action="override">
          <value>nosniff</value>
        </set-header>
        <set-header name="Strict-Transport-Security" exists-action="override">
          <value>max-age=31536000; includeSubDomains</value>
        </set-header>
        
        <!-- Rate limiting by tenant -->
        <rate-limit-by-key calls="1000" renewal-period="60" counter-key="@(context.Request.Headers.GetValueOrDefault("X-Tenant-ID","anonymous"))" />
        
        <!-- Tenant validation -->
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">
          <openid-config url="${environment().authentication.loginEndpoint}common/v2.0/.well-known/openid_configuration" />
          <required-claims>
            <claim name="aud">
              <value>api://stamps-pattern</value>
            </claim>
          </required-claims>
        </validate-jwt>
        
        <!-- Log tenant access for analytics -->
        <log-to-eventhub logger-id="tenant-analytics">
          @{
            return new JObject(
              new JProperty("timestamp", DateTime.UtcNow),
              new JProperty("tenantId", context.Request.Headers.GetValueOrDefault("X-Tenant-ID","")),
              new JProperty("operation", context.Operation.Name),
              new JProperty("requestId", context.RequestId)
            ).ToString();
          }
        </log-to-eventhub>
      </inbound>
      <backend>
        <forward-request />
      </backend>
      <outbound>
        <!-- Remove sensitive headers -->
        <set-header name="Server" exists-action="delete" />
        <set-header name="X-Powered-By" exists-action="delete" />
      </outbound>
      <on-error>
        <!-- Error logging -->
        <log-to-eventhub logger-id="error-analytics">
          @{
            return new JObject(
              new JProperty("timestamp", DateTime.UtcNow),
              new JProperty("error", context.LastError.Message),
              new JProperty("requestId", context.RequestId)
            ).ToString();
          }
        </log-to-eventhub>
      </on-error>
    </policies>
    '''
    format: 'xml'
  }
}

// Tenant Management API
resource tenantManagementApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  name: 'tenant-management-api'
  parent: apim
  properties: {
    displayName: 'Tenant Management API'
    description: 'API for managing tenant lifecycle, user access, and CELL routing'
    serviceUrl: 'https://functions-${location}.azurewebsites.net/api'
    path: 'tenant'
    protocols: ['https']
    subscriptionRequired: true
    apiVersion: 'v1'
    apiVersionSetId: tenantApiVersionSet.id
  }
}

// API Version Set for tenant management
resource tenantApiVersionSet 'Microsoft.ApiManagement/service/apiVersionSets@2023-05-01-preview' = {
  name: 'tenant-api-versions'
  parent: apim
  properties: {
    displayName: 'Tenant Management API Versions'
    description: 'Version set for tenant management APIs'
    versioningScheme: 'Header'
    versionHeaderName: 'Api-Version'
  }
}

// Products for different tenant tiers
resource basicTierProduct 'Microsoft.ApiManagement/service/products@2023-05-01-preview' = {
  name: 'basic-tier'
  parent: apim
  properties: {
    displayName: 'Basic Tier'
    description: 'Basic API access for starter tenants'
    state: 'published'
    subscriptionRequired: true
    approvalRequired: false
    terms: 'Basic tier terms and conditions'
  }
}

resource premiumTierProduct 'Microsoft.ApiManagement/service/products@2023-05-01-preview' = {
  name: 'premium-tier'
  parent: apim
  properties: {
    displayName: 'Premium Tier'
    description: 'Premium API access with higher limits and SLA'
    state: 'published'
    subscriptionRequired: true
    approvalRequired: true
    terms: 'Premium tier terms and conditions with SLA guarantees'
  }
}

// Basic tier rate limiting policy
resource basicTierPolicy 'Microsoft.ApiManagement/service/products/policies@2023-05-01-preview' = {
  name: 'policy'
  parent: basicTierProduct
  properties: {
    value: '''
    <policies>
      <inbound>
        <rate-limit calls="10000" renewal-period="3600" />
        <quota calls="100000" renewal-period="86400" />
      </inbound>
      <backend>
        <forward-request />
      </backend>
      <outbound />
      <on-error />
    </policies>
    '''
    format: 'xml'
  }
}

// Premium tier rate limiting policy
resource premiumTierPolicy 'Microsoft.ApiManagement/service/products/policies@2023-05-01-preview' = {
  name: 'policy'
  parent: premiumTierProduct
  properties: {
    value: '''
    <policies>
      <inbound>
        <rate-limit calls="50000" renewal-period="3600" />
        <quota calls="1000000" renewal-period="86400" />
      </inbound>
      <backend>
        <forward-request />
      </backend>
      <outbound />
      <on-error />
    </policies>
    '''
    format: 'xml'
  }
}

// Diagnostic settings for APIM
resource apimDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${apimName}-diagnostics'
  scope: apim
  properties: {
    workspaceId: globalLogAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
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

@description('Additional locations for geo-replication (array of region names, e.g., ["westus2"])')
param additionalLocations array

// Flatten the list of Cosmos DB locations
var additionalCosmosDbLocations = [for (loc, idx) in additionalLocations: {
  locationName: string(loc)
  failoverPriority: idx + 1
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
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: cosmosDbLocations
    enableMultipleWriteLocations: true
    databaseAccountOfferType: 'Standard'
  }
}

// Outputs
output apimGatewayUrl string = apim.properties.gatewayUrl
output apimDeveloperPortalUrl string = apim.properties.developerPortalUrl
output apimManagementApiUrl string = apim.properties.managementApiUrl
output apimResourceId string = apim.id
output globalControlCosmosDbEndpoint string = globalControlCosmosDb.properties.documentEndpoint
output globalControlCosmosDbId string = globalControlCosmosDb.id
