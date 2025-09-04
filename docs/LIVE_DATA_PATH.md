---
# Live Data Path — Portal → GraphQL → Cosmos (quick guide)

Purpose

- One-page smoke path and quick checks to validate the Management Portal consumes live data from the GraphQL backend (Hot Chocolate) backed by Cosmos DB.

Who this is for

- Developers, platform engineers, and operators who need a fast, repeatable set of checks to confirm the live-data flow is healthy.

Overview

- Path: Management Portal (UI) → GraphQL backend (Hot Chocolate) → Cosmos DB (control-plane containers: tenants, cells, operations)
- Secrets and identity: Portal authenticates users via AAD; Portal calls the GraphQL backend over the internal network; the GraphQL backend uses a managed identity or connection string to read Cosmos.

Quick diagram

```mermaid
flowchart LR
  Portal[Management Portal]
  GraphQL[GraphQL (Hot Chocolate) (Container App)]
  Cosmos[Cosmos DB - stamps-control-plane]

  Portal -->|HTTP GraphQL POST| GraphQL
  GraphQL -->|Cosmos SDK / REST| Cosmos
```mermaid

Essential variables

 - GraphQL URL (secret): GRAPHQL_URL — e.g. https://<internal-fqdn>/graphql
 - Portal secret/setting: ensure Portal reads the GraphQL URL from container-app secrets or Key Vault

Note: The GraphQL backend used in this project is Hot Chocolate.
- Seeder location: `AzureArchitecture/Seeder` (uses DefaultAzureCredential)

Smoke checks (fast)

1) Validate GraphQL backend is healthy (Container Apps)

# List revisions and health
az containerapp revision list -g rg-stamps-mgmt -n ca-stamps-graphql -o table

# Show ingress configuration (confirm targetPort matches container)
az containerapp show -g rg-stamps-mgmt -n ca-stamps-graphql --query properties.configuration.ingress

2) Tail GraphQL backend logs (look for startup errors and GraphQL listening)

```powershell
az containerapp logs show -g rg-stamps-mgmt -n ca-stamps-graphql --container dab --tail 200
```

1) Quick GraphQL introspection / simple query

Using PowerShell (Invoke-RestMethod) — replace `$graphql` with the GraphQL backend URL:

```powershell
$graphql = 'https://<graphql-backend-fqdn>/graphql'
$body = @{ query = 'query { __schema { queryType { name } } }' } | ConvertTo-Json

# Use -UseBasicParsing if needed in older PowerShell
Invoke-RestMethod -Uri $graphql -Method Post -ContentType 'application/json' -Body $body
```

Or curl (if available):

```powershell
```bash
curl -s -X POST $graphql -H "Content-Type: application/json" -d '{"query":"{ tenants { tenantId name } }"}' | jq
```

Expected results

- Introspection returns a schema object (or tenants query returns a JSON list). If requests time out, the GraphQL backend is not responding — check container logs and ingress.

Seeder (run locally or in CI)

The seeder project uses `DefaultAzureCredential` and requires an identity with Cosmos DB Data Contributor on the `stamps-control-plane` account.
From the workspace root (PowerShell):

```powershell
# Build and run the seeder (example path)
dotnet build ./AzureArchitecture/Seeder/Seeder.csproj
dotnet run --project ./AzureArchitecture/Seeder/Seeder.csproj -- --environment dev
```

Notes

- If the seeder receives 401/403, ensure the principal (local user/service principal/managed identity) has the Cosmos DB Data Contributor role and firewall rules allow access.
- If the GraphQL backend responds but returns schema errors, validate the Hot Chocolate backend configuration.

Troubleshooting quick hits

- Container crashing: tail GraphQL backend logs and search for missing files, permission errors, or command not found.
- Port mismatch: confirm Dockerfile exposes the same port referenced by container app `targetPort` (common mismatch: 5000 vs 80).
- Portal timeouts: check Portal GraphQL URL secret, ensure it points to the internal FQDN/proxy, and confirm network egress/ingress rules.

Related docs

- `docs/AUTH_CI_STRATEGY.md` — authentication and CI notes
- `management-portal/infra/management-portal.bicep` — IaC for GraphQL backend and Portal

1) Quick smoke checks

- Test GraphQL backend health (replace host):

```powershell
# PowerShell: introspection (may be disabled in prod)
Invoke-RestMethod -Method Post -Uri "https://<graphql-backend-fqdn>/graphql" -Body '{"query":"{ __schema { types { name } } }"}' -ContentType 'application/json'
```

- Basic GraphQL query (Tenants):

```powershell
# Tenants query (PowerShell)
$q = '{"query":"query { tenants { tenantId displayName } }"}';
Invoke-RestMethod -Method Post -Uri "https://<graphql-backend-fqdn>/graphql" -Body $q -ContentType 'application/json'
```

  # curl (Linux/macOS or WSL)

```powershell
curl -s -X POST https://<graphql-backend-fqdn>/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"query { tenants { tenantId displayName } }"}'
```

  # Expected (example) response snippet

```json
{ "data": { "tenants": [ { "tenantId": "tenant-001", "displayName": "Acme Ltd" } ] } }
```

- If the portal times out, check Container App logs:

```powershell
az containerapp revision list --name ca-stamps-graphql --resource-group rg-stamps-mgmt --output table
az containerapp logs show --name ca-stamps-graphql --resource-group rg-stamps-mgmt --revision <revision-name>
```

1) Common failures & where to look

- GraphQL backend returns 502/503: check container health (port mismatch, missing configuration, or startup errors).
- GraphQL errors about types/fields: confirm the Hot Chocolate backend schema aligns with portal queries.
- Cosmos permission errors: verify the identity (managed identity or service principal) has the Cosmos DB Data Contributor role on the database.

1) GraphQL mutations the portal may call (examples)

## Reserve domain / create tenant (example mutation)

```graphql
mutation CreateTenant($input: CreateTenantInput!) {
  createTenant(input: $input) { tenantId displayName }
}
```

## Example JSON body for curl

```json
{"query":"mutation CreateTenant($input: CreateTenantInput!){createTenant(input:$input){tenantId displayName}}","variables":{"input":{"displayName":"New Tenant","tenantId":"tenant-123"}}}
```

## If mutations fail with 401/403, check

- DAB auth mode (static vs managed identity)
- The Portal's `DAB_GRAPHQL_URL` is the correct internal FQDN (and secret matches)

1) Seeder quick run

- Run the seeder with a principal that has data contributor rights; locally DefaultAzureCredential will use your Azure CLI identity.

## Notes

- Internal DAB FQDN may be private to the Container Apps environment; use `az containerapp show` to fetch the ingress if exposed or consult deployment outputs.


- **Version**: 1.4.0
- **Last Updated**: 2025-08-18 01:08:00 UTC  
- **Status**: Current
- **Next Review**: 2025-11

---

**📝 Document Version Information**
- **Version**: 1.6.3
- **Last Updated**: 2025-09-03 13:38:15 UTC  
- **Status**: Current
- **Next Review**: 2025-11
