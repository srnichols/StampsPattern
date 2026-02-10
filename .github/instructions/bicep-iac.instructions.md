# Bicep & Infrastructure as Code — Coding Instructions

applyTo: "AzureArchitecture/**/*.bicep,infra/**/*.bicep,traffic-routing.bicep"

## Scope & Orchestration

- Top-level `main.bicep` uses `targetScope = 'subscription'`
- Modules follow a layered architecture:
  - `globalLayer.bicep` — DNS Zone, Traffic Manager, Front Door, global Function Apps, global Cosmos DB
  - `geodesLayer.bicep` — APIM (Premium/Developer), global control plane Cosmos DB
  - `regionalLayer.bicep` — Regional networking and services
  - `deploymentStampLayer.bicep` — Per-CELL resources (SQL, Storage, Key Vault, Container Apps, App Gateway)
  - `monitoringLayer.bicep` — Log Analytics, dashboards, monitoring
- Resource groups are created at subscription scope: `rg-stamps-{scope}-{environment}`

## Naming Conventions

- Resource groups: `rg-stamps-{scope}-{environment}` (e.g., `rg-stamps-global-test`)
- Resources follow Azure CAF abbreviations: `fd-` (Front Door), `tm-` (Traffic Manager), `fa-` (Function App), `st` (Storage), `kv-` (Key Vault), `apim-` (API Management), `cosmos-` (Cosmos DB)
- Use `uniqueString(resourceGroup().id, salt)` for globally unique resource names
- See `docs/NAMING_CONVENTIONS_GUIDE.md` for the full reference

## Parameters

- Always use `@description()` decorators on every parameter
- Always use `@secure()` for passwords, connection strings, and secret values
- Use `@allowed()` for constrained values (environments, SKUs, storage tiers)
- Use environment-aware defaults: `param value string = (environment == 'prod' ? 'prodValue' : 'devValue')`
- Environment enum: `dev`, `test`, `staging`, `prod`
- Provide a `salt` parameter for unique name generation across deployments

## Environment-Aware Patterns

- APIM SKU: `Developer` for non-prod, `Premium` for prod
- Cosmos DB zone redundancy: `true` in prod, `false` otherwise
- SQL SKU: `S1` in prod, `S0` in non-prod
- Defender for Cloud plans: Free/Off in non-prod, Standard/P1 in prod
- Container App Environment: toggleable via `enableContainerAppEnvironment`
- Storage SKU: `Premium_ZRS` default for CELLs, `Standard_LRS` for global

## Security

- TLS 1.0 and 1.1 explicitly disabled on all APIM instances
- APIM policies include: security headers (`X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, HSTS), rate limiting per tenant, JWT validation
- Sensitive headers (`Server`, `X-Powered-By`) removed from outbound responses
- Private endpoints available for Cosmos DB, SQL, Storage (toggle via `enablePrivateEndpoints`)
- Application Gateway WAF available per CELL (toggle via `enableApplicationGateway`)

## Cost Optimization

- Defender plans have individual toggles: `enableDefenderForStorage`, `enableDefenderForSql`, `enableDefenderForAppServices`, `enableDefenderForKeyVault`
- CSPM (Arm) always remains at Free tier for secure score and policy
- `enableGlobalFunctions` toggle to skip Function Apps in smoke/lab environments
- `enableCellTrafficManager` defaults to false (global TM in global layer)
- `enableContainerRegistry` defaults to false in smoke deployments

## Diagnostics & Monitoring

- All resources should send diagnostics to the central Log Analytics workspace
- Pass `globalLogAnalyticsWorkspaceId` through the module chain from `main.bicep`
- Container App Environments also need `logAnalyticsCustomerId` (workspace GUID)

## Bicep Linting

- Linter config: `bicepconfig.json` with warnings for `no-unused-params`, `no-unused-vars`, `prefer-interpolation`
- Prefer string interpolation over `concat()` function
- Use comments to explain complex logic, removed parameters, and cross-module dependencies

## Output Conventions

- Expose critical resource IDs and URLs as outputs: APIM gateway URLs, Cosmos DB endpoints, Log Analytics workspace IDs
- Use meaningful output names: `apimGatewayUrl`, `logAnalyticsWorkspaceCustomerId`, `debugLogAnalyticsCustomerId`
