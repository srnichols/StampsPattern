// APIM global policy XML with parameterized tenant ID (EventHub logging removed temporarily)
var apimGlobalPolicyXml = '<policies>\n  <inbound>\n    <!-- Global security headers -->\n    <set-header name="X-Frame-Options" exists-action="override">\n      <value>DENY</value>\n    </set-header>\n    <set-header name="X-Content-Type-Options" exists-action="override">\n      <value>nosniff</value>\n    </set-header>\n    <set-header name="Strict-Transport-Security" exists-action="override">\n      <value>max-age=31536000; includeSubDomains</value>\n    </set-header>\n    <!-- Rate limiting by tenant -->\n    <rate-limit-by-key calls="1000" renewal-period="60" counter-key="@(context.Request.Headers.GetValueOrDefault(&quot;X-Tenant-ID&quot;,&quot;anonymous&quot;))" />\n    <!-- Tenant validation -->\n    <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">\n      <openid-config url="${environment().authentication.loginEndpoint}${entraTenantId}/v2.0/.well-known/openid-configuration" />\n      <required-claims>\n        <claim name="aud">\n          <value>api://stamps-pattern</value>\n        </claim>\n      </required-claims>\n    </validate-jwt>\n  </inbound>\n  <backend>\n    <forward-request />\n  </backend>\n  <outbound>\n    <!-- Remove sensitive headers -->\n    <set-header name="Server" exists-action="delete" />\n    <set-header name="X-Powered-By" exists-action="delete" />\n  </outbound>\n  <on-error>\n    <!-- Error logging to Log Analytics -->\n    <trace source="@(context.RequestId)" severity="error">\n      @{\n        return new JObject(\n          new JProperty("timestamp", DateTime.UtcNow),\n          new JProperty("error", context.LastError.Message),\n          new JProperty("requestId", context.RequestId)\n        ).ToString();\n      }\n    </trace>\n  </on-error>\n</policies>'
@description('Entra ID Tenant ID for APIM OpenID configuration')
param entraTenantId string
@description('Deployment environment name (e.g., dev, test, prod)')
param deploymentEnvironment string = 'test'
// cosmosZoneRedundant is handled by the top-level orchestrator (main.bicep)
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
// Determine APIM SKU: Developer for non-prod (demo/dev), Premium for prod
var apimSkuName = deploymentEnvironment == 'prod' ? 'Premium' : 'Developer'
// Common APIM configuration fragments
var apimCustomProperties = {
  'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
  'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
  'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
  'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
  'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
}

var apimApiVersionConstraint = {
  minApiVersion: '2021-08-01'
}
resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: apimSkuName
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    virtualNetworkType: 'None'
    // additionalLocations is intentionally left empty here; main.bicep controls multi-region per environment
    additionalLocations: []
    customProperties: apimCustomProperties
    apiVersionConstraint: apimApiVersionConstraint
  }
  tags: tags
}

// Create additional independent APIM instances (Developer/Standard) in specified regions for demo HA/DR
// Deploy per-region APIM instances via child module to safely capture runtime outputs
// Secondary APIMs are deployed by the top-level orchestrator (main.bicep) as module instances
// to allow collection of authoritative runtime outputs. Keep apimAdditionalRegions parameter
// for the orchestrator to use.

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

// The global control Cosmos DB account is created by the top-level orchestrator
// (`main.bicep`). We keep the parameter here for documentation parity but do not
// create the resource inside this module.

// NOTE: The global control Cosmos DB is owned by the top-level orchestrator to avoid
// duplicate definitions across modules. Do NOT create the account here. Instead,
// reference the orchestrator-owned account by name when needing the endpoint/ID.

// Outputs
output apimGatewayUrl string = apim.properties.gatewayUrl

// Build secondary APIM instance names and their expected gateway URLs without referencing resource collections.
// Compute secondary APIM instance names and deterministic gateway hostnames to wire Front Door.
// We avoid indexing module outputs here because module outputs may not be available at template start.
var apimSecondaryNames = [for r in apimAdditionalRegions: '${apimName}-${replace(string(r), ' ', '-') }']
var apimSecondaryGatewayUrlsComputed = [for n in apimSecondaryNames: format('https://{0}.azure-api.net', toLower(n))]

// Use deterministic hostnames for downstream wiring (safe and deterministic for demo). If you
// prefer authoritative runtime hostnames, read module outputs from a parent orchestrator after
// the modules have completed.
output apimSecondaryGatewayUrls array = apimSecondaryGatewayUrlsComputed
output apimGatewayUrls array = concat([apim.properties.gatewayUrl], apimSecondaryGatewayUrlsComputed)
output apimDeveloperPortalUrl string = apim.properties.developerPortalUrl
output apimManagementApiUrl string = apim.properties.managementApiUrl
output apimResourceId string = apim.id
// Reference orchestrator-owned Cosmos DB by resourceId to avoid duplicate creation.
// Cosmos DB is created in globalLayer; expose its details from that module instead.
