# 👩‍💻 Developer Quickstart

A concise, step-by-step path to clone, configure, run, and debug the Functions app locally with Cosmos Emulator. Links out to deeper guides where needed.

## ✅ Prerequisites

- Windows, macOS, or Linux with PowerShell 7+
- .NET SDK 6.x+
- Node.js + npm (for Azure Functions Core Tools)
- Docker Desktop (for Cosmos DB Emulator container) or the Windows emulator

Optional:

- Azurite (local Storage emulator)
- Redis (if you want to exercise the Redis-based cache path; otherwise memory cache is used)

## 1) Clone and open the repo

```powershell
git clone https://github.com/srnichols/StampsPattern.git
cd StampsPattern
```

## 2) Start local data stack (scripted)

Recommended: use the helper to start Cosmos Emulator, DAB, and the portal.

```powershell
pwsh -File ./scripts/run-local.ps1
```

Default ports: Cosmos 8085, DAB 8082, Portal 8081. The script also helps trust the emulator cert.

Manual alternative (optional):

- Start Azurite: `azurite --silent --location ./.azurite --debug ./.azurite/debug.log`
- Start Cosmos Emulator (container) and ensure it exposes 8085

More: See Deployment Guide → Run locally (Functions + Emulator).

## 3) Configure local.settings.json

File: `AzureArchitecture/local.settings.json`.
At minimum set Cosmos and identity settings:

```jsonc
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true", // Azurite
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    // Cosmos Emulator
    "CosmosDbConnection": "AccountEndpoint=https://localhost:8085/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==",
    "CosmosDbDatabaseName": "globaldb",
    "TenantsContainerName": "tenants",
    "CellsContainerName": "cells",
    // Identity (Microsoft Entra External ID)
    "EXTERNAL_ID_TENANT": "your-tenant-name.onmicrosoft.com",
    "EXTERNAL_ID_CLIENT_ID": "00000000-0000-0000-0000-000000000000",
    "EXTERNAL_ID_USER_FLOW": "B2C_1_signupsignin",
    // Legacy fallback keys still supported if present
    // "B2C_TENANT": "your-b2c-tenant",
    // "B2C_CLIENT_ID": "your-client-id",
    // "B2C_POLICY": "your-policy"
  }
}
```jsonc

Tip: The emulator account key shown above is the standard sample key; adjust if your emulator differs.

## 4) Install Azure Functions Core Tools v4

```powershell
npm i -g azure-functions-core-tools@4
func --version   # expect major version 4
```

If `func` isn’t found, ensure your npm global bin is on PATH.

## 5) Build and run the Functions app

```powershell
```powershell
cd ./AzureArchitecture
 dotnet build
 func start
```

If the default port is busy, try `func start --port 7072`.

Endpoints (once running):

- Health:    <http://localhost:7071/api/health>
- SwaggerUI: <http://localhost:7071/api/swagger/ui>
- ApiInfo:   <http://localhost:7071/api/api/info>

## 6) Troubleshooting local run

Common fixes:

```powershell
# Verbose logs
func start --verbose

# Ensure local.settings.json targets the emulator
# If SSL trust fails, open once: https://localhost:8085/_explorer/emulator.pem

# Avoid overlapping builds/hosts
# Stop any running VS Code tasks and background func hosts.

# Check port conflicts, try another port
func start --port 7072
```bash

See also: Known Issues → Functions host exits on startup or endpoints not reachable locally.

## 🎯 Minimal Happy Path (Live Data)


This section shows the recommended end-to-end steps to deploy a minimal cloud lab, seed representative data using the seeder, and verify the Management Portal shows live data through the integrated Hot Chocolate GraphQL API. We place this after local setup and verification because it assumes your development environment and credentials are configured.

Prerequisites (cloud): Azure CLI, PowerShell 7+, Bicep CLI, and an Azure subscription with Contributor access for the target resource group.

Steps:

1. From the repository root, deploy a smoke/lab environment (example PowerShell):

```powershell
pwsh -File ./scripts/deploy-stamps.ps1 -ResourceGroupName rg-stamps-smoke -Location eastus -TenancyModel shared
```

Or deploy manually with Bicep:

```powershell
az group create -n rg-stamps-smoke -l eastus
az deployment group create -g rg-stamps-smoke -f traffic-routing.bicep --parameters @AzureArchitecture/examples/main.sample.smoke.json
```

1. Wait for deployment to finish; note the Management Portal URL and the GraphQL API endpoint outputs from the deployment.

1. Seed baseline data: run the seeder in `AzureArchitecture/Seeder`. The seeder uses `DefaultAzureCredential` so your signing principal must have the Cosmos DB Data Contributor role on the target account. See `AzureArchitecture/README.md` or `docs/LIVE_DATA_PATH.md` for seeder options.

1. Verify the Hot Chocolate GraphQL API is healthy: POST a simple GraphQL query to the endpoint (e.g., <http://localhost:8082/graphql> or the deployed URL). You can use Banana Cake Pop, Insomnia, Postman, or curl. See `docs/LIVE_DATA_PATH.md` for the exact query and examples.

1. Open the Management Portal URL and sign in; confirm Tenants and Cells are visible and resolve through the portal UI.

1. If you see no data, check the following:

- Container App logs for the Portal (`ca-stamps-portal`).
- Confirm the GraphQL API responds directly with a simple query.
- Ensure the seeder principal has the correct RBAC role on Cosmos (Cosmos DB Data Contributor).

1. For auth or CI/OIDC troubleshooting, see `docs/AUTH_CI_STRATEGY.md`.

When complete, continue to the full <a href="./DEPLOYMENT_GUIDE.md" target="_blank" rel="noopener" title="Opens in a new tab">Deployment Guide</a> for production hardening and <a href="./PARAMETERIZATION_GUIDE.md" target="_blank" rel="noopener" title="Opens in a new tab">parameterization</a>.

## 7) Quick code tour

Where to look when extending features:

- `Program.cs`: DI setup for CosmosClient, caching (Redis or memory), and worker configuration.
- `DocumentationFunction.cs`: Swagger UI, Health, ApiInfo routes.
- `GetTenantInfoFunction.cs`: Identity inputs; EXTERNAL_ID_*and legacy B2C_* fallback handling.
- `CachingService.cs`: Redis/in-memory cache patterns and endpoints.
- `CellManagementFunction.cs`: Timer trigger optionalized; HTTP fallback `MonitorCellCapacityNow`.
- `host.json`: HTTP route prefix and concurrency options.

## 8) CI and profiles (for devs integrating infra)

- Profiles: `environmentProfile` supports `smoke`, `dev`, `prod`.
  - smoke → metrics-only diagnostics, HTTP-friendly lab toggles
  - dev/prod → standard/full diagnostics
- CI: GitHub Actions include Bicep lint and What-If. Use the Matrix workflow to preview changes across profiles.

Links:

- Run locally (Functions + Emulator): Deployment Guide → Run locally
- Developer Security Guide: identity settings, caching, DI, JWT validation
- Parameterization Guide: profiles, diagnosticsMode, JSON examples
- Known Issues: local run, emulator, and deployment troubleshooting

---

**📝 Document Version Information**
- **Version**: 1.6.3
- **Last Updated**: 2025-09-03 13:38:15 UTC  
- **Status**: Current
- **Next Review**: 2025-11
