// --------------------------------------------------------------------------------------
// Azure AD B2C Tenant Setup (one-time, global, not per CELL)
// Note: Azure AD B2C tenant creation is not supported directly in Bicep/ARM.
// This template creates an Azure AD B2C resource in your subscription, referencing an existing B2C tenant.
// --------------------------------------------------------------------------------------

@description('The name of your Azure AD B2C tenant (e.g., sdpsaasb2c.onmicrosoft.com)')
param b2cTenantName string

@description('The location for the B2C resource (must be "United States")')
param location string = 'United States'

resource b2cDirectory 'Microsoft.AzureActiveDirectory/b2cDirectories@2019-01-01-preview' = {
  name: b2cTenantName
  location: location
  properties: {
    // No additional properties required for linking
  }
}

output b2cTenantResourceId string = b2cDirectory.id
output b2cTenantName string = b2cTenantName

// --------------------------------------------------------------------------------------
// NOTE: You must create the actual Azure AD B2C tenant via the Azure Portal first.
// This Bicep file links the B2C tenant to your subscription for resource management.
// --------------------------------------------------------------------------------------
