# Security — Instructions

applyTo: "AzureArchitecture/**/*.cs,AzureArchitecture/zeroTrustSecurity.bicep,AzureArchitecture/advancedSecurity.bicep,AzureArchitecture/defenderPlans.bicep,AzureArchitecture/globalIdentity*.bicep"

## Zero-Trust Architecture

This solution implements defense-in-depth with zero-trust principles at every layer.

### Network Security

- **Default deny-all** inbound and outbound rules on NSGs
- Explicitly allow only:
  - HTTPS (443) from Application Gateway subnet to workload subnet
  - Internal communication within workload subnets (80, 443)
  - Outbound to Azure services via service tags
- Private endpoints for data services (Cosmos DB, SQL Server, Storage, Key Vault)
- Application Gateway with WAF v2 per CELL (toggleable: `enableApplicationGateway`)
- Front Door WAF at the global edge

### Authentication & Authorization

#### Microsoft Entra External ID (customers)

- Primary identity provider for tenant users (replaces legacy Azure AD B2C)
- JWT validation via OIDC discovery endpoint with JWKS caching (24-hour TTL)
- Configuration env vars:
  - `EXTERNAL_ID_TENANT` — Entra External ID tenant name
  - `EXTERNAL_ID_CLIENT_ID` — Application (client) ID
  - `EXTERNAL_ID_USER_FLOW` — user flow/policy name
- Fallback to legacy B2C env vars (`B2C_TENANT`, `B2C_CLIENT_ID`, `B2C_POLICY`)

#### JWT Validation Pattern

```csharp
// Always validate: issuer, audience, lifetime, signing key
var validationParameters = new TokenValidationParameters
{
    ValidIssuer = authority,
    ValidAudiences = new[] { clientId },
    IssuerSigningKeys = config.SigningKeys,
    ValidateIssuer = true,
    ValidateAudience = true,
    ValidateLifetime = true,
    ValidateIssuerSigningKey = true,
    ClockSkew = TimeSpan.FromMinutes(5)
};
```

- Cache JWKS in `MemoryCache` (key: `jwks_{tenant}_{policy}`, 24-hour TTL)
- Use `JsonWebTokenHandler` (not `JwtSecurityTokenHandler`) for validation
- Return 401 Unauthorized for any validation failure — never leak error details

#### Management Portal Auth

- Microsoft Identity Web (`Microsoft.Identity.Web`)
- OpenID Connect with Azure AD
- Role-based policies: `PlatformAdmin` (role: `platform.admin`), `Authenticated`
- Force HTTPS redirect URIs in production
- `FallbackPolicy = DefaultPolicy` — authentication required by default

### APIM Security Policies

Applied globally at the API Management layer:

```xml
<!-- Security headers -->
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Strict-Transport-Security: max-age=31536000; includeSubDomains

<!-- Rate limiting per tenant -->
rate-limit-by-key: 1000 calls/60s keyed on X-Tenant-ID header

<!-- JWT validation at gateway -->
validate-jwt: Entra ID issuer, audience api://stamps-pattern

<!-- Strip sensitive response headers -->
Remove: Server, X-Powered-By
```

### TLS Configuration

- TLS 1.0 and 1.1 explicitly disabled on APIM
- TLS 1.2+ enforced for all backend communications
- SSL 3.0 disabled for backend connections

### Managed Identity

- System-assigned managed identity on APIM
- User-assigned managed identity for deployment scripts and automation
- `DefaultAzureCredential` used in all application code — picks MI in Azure, CLI/VS creds locally
- Cosmos DB data-plane access via `Cosmos DB Built-in Data Contributor` role
- ACR access via `AcrPull` role

### Secrets Management

- All secrets stored in **Azure Key Vault** in production
- Key Vault naming: `secrets/cosmos-conn`, `secrets/acr-credentials`, `secrets/graphql-config`
- Function Apps use `@secure()` parameters — never hardcode secrets in Bicep
- `local.settings.json` for dev only — never commit real secrets
- Cosmos DB connection string stored in Key Vault via deployment script with retry logic

### Azure Policy as Code

- Custom policies enforced at management group scope:
  - **CAF naming conventions** for storage accounts
  - **Require managed identity** on all supported resources
- Enforcement modes: `Default` (prod), `DoNotEnforce` (audit-only for dev/test)

### Microsoft Defender for Cloud

- Environment-aware toggles:
  - `defenderForServersPlan`: Off (dev) / P1 (prod)
  - `enableDefenderForStorage`: false (dev) / true (prod)
  - `enableDefenderForSql`: false (dev) / true (prod)
  - `enableDefenderForAppServices`: false (default)
  - `enableDefenderForKeyVault`: false (default)
- CSPM (ARM) always at Free tier for secure score and policy evaluation

### Security Code Conventions

- Never log secrets, tokens, or connection strings
- Always validate input before processing (tenantId, subdomain, request payloads)
- Use parameterized Cosmos DB queries — never interpolate user input into queries
- Return generic error messages to clients; log detailed errors server-side
- Use `AuthorizationLevel.Function` on all operational endpoints
- Only health check and documentation endpoints may be `Anonymous`
