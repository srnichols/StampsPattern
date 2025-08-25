// APIM global policy XML with parameterized tenant ID (EventHub logging removed temporarily)
var apimGlobalPolicyXml = '<policies>\n  <inbound>\n    <!-- Global security headers -->\n    <set-header name="X-Frame-Options" exists-action="override">\n      <value>DENY</value>\n    </set-header>\n    <set-header name="X-Content-Type-Options" exists-action="override">\n      <value>nosniff</value>\n    </set-header>\n    <set-header name="Strict-Transport-Security" exists-action="override">\n      <value>max-age=31536000; includeSubDomains</value>\n    </set-header>\n    <!-- Rate limiting by tenant -->\n    <rate-limit-by-key calls="1000" renewal-period="60" counter-key="@(context.Request.Headers.GetValueOrDefault(&quot;X-Tenant-ID&quot;,&quot;anonymous&quot;))" />\n    <!-- Tenant validation -->\n    <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">\n      <openid-config url="${environment().authentication.loginEndpoint}${entraTenantId}/v2.0/.well-known/openid-configuration" />\n      <required-claims>\n        <claim name="aud">\n          <value>api://stamps-pattern</value>\n        </claim>\n      </required-claims>\n    </validate-jwt>\n  </inbound>\n  <backend>\n    <forward-request />\n  </backend>\n  <outbound>\n    <!-- Remove sensitive headers -->\n    <set-header name="Server" exists-action="delete" />\n    <set-header name="X-Powered-By" exists-action="delete" />\n  </outbound>\n  <on-error>\n    <!-- Error logging to Log Analytics -->\n    <trace source="@(context.RequestId)" severity="error">\n      @{\n        return new JObject(\n          new JProperty("timestamp", DateTime.UtcNow),\n          new JProperty("error", context.LastError.Message),\n          new JProperty("requestId", context.RequestId)\n        ).ToString();\n      }\n    </trace>\n  </on-error>\n</policies>'
@description('Entra ID Tenant ID for APIM OpenID configuration')
param entraTenantId string
@description('Enable zone redundancy for Cosmos DB (true = zone redundant, false = non-zonal)')
param cosmosZoneRedundant bool = true
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

@description('Custom domain for APIM (e.g., api.sdp-saas.com)')
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
      location: string(region)
      sku: {
        name: 'Premium'
        capacity: 1
      }
      zones: []
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
    value: apimGlobalPolicyXml
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
        <rate-limit calls="10000" renewal-period="300" />
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
        <rate-limit calls="50000" renewal-period="300" />
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
  isZoneRedundant: false
}]

var cosmosDbLocations = concat(
  [
    {
      locationName: primaryLocation
      failoverPriority: 0
      isZoneRedundant: cosmosZoneRedundant
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
