// --------------------------------------------------------------------------------------
// Microsoft Entra External ID for customers (formerly Azure AD B2C) - Legacy Template Notice
// IMPORTANT: Creating or linking an External ID (B2C) tenant is not supported via Bicep/ARM.
// Action: Create/configure your External ID tenant manually in the Azure portal and configure app registrations & user flows there.
// This file is intentionally a no-op to keep CI green and document intent.
// --------------------------------------------------------------------------------------

@description('Optional: external ID (B2C) tenant name for documentation only (e.g., contosoextid.onmicrosoft.com)')
param externalIdTenantName string = ''

@description('Informational message output')
output message string = 'External ID tenant must be created and configured manually in the Azure portal. This template is a no-op.'

@description('Echo of provided tenant name (if any)')
output externalIdTenant string = externalIdTenantName
// NOTE: Create your Microsoft Entra External ID (customers) tenant via the Azure portal first.
// There is no ARM/Bicep support to create or link these tenants.
// --------------------------------------------------------------------------------------
