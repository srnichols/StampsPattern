# Management Portal

Run locally with one command or via the AppHost. Defaults to in-memory data; set DAB_GRAPHQL_URL to point to your Data API Builder GraphQL endpoint to use real data.

## Auth and roles (production)

- Hosting: Azure Container Apps (ACA) for the portal and DAB API; Azure Functions for command handlers.
- DAB auth provider: AppService (uses Easy Auth-compatible headers). In ACA and Functions, enable the built-in authentication and require login.
- Roles in DAB: `authenticated` (read) and `platform.admin` (CRUD).
- Map Entra ID security groups to roles via `X-MS-CLIENT-PRINCIPAL` claims emitted by ACA/Functions auth. Ensure your admin group objectId resolves to `platform.admin`.

## Local Run (one command)
- Start: pwsh -File .\scripts\run-local.ps1
- Stop: pwsh -File .\scripts\stop-local.ps1
- Portal: http://localhost:8081
- GraphQL: http://localhost:8082/graphql
- Cosmos Emulator: https://localhost:8085

## Local Run (AppHost)
- Build AppHost: dotnet build management-portal/AppHost
- Run AppHost: dotnet run --project management-portal/AppHost
- Portal URL: http://localhost:8081

Prereqs for Aspire run (CLI)
- .NET 9 SDK installed (9.0.4xx or newer)
- .NET Aspire 9 workload and tools installed
	- dotnet workload install aspire
	- Ensure Aspire Hosting SDK pack is 9.x under C:\Program Files\dotnet\packs\Aspire.Hosting.Sdk
	- Install Aspire Distributed Control Plane (DCP) and Aspire Dashboard (via Visual Studio Installer > Individual components > .NET Aspire 9)
- CLI: aspire --version should show 9.x

Troubleshooting
- If aspire run says "not an Aspire app host project" or AppHost complains about missing DCP/Dashboard, install the Aspire 9 SDK pack and DCP/Dashboard as above.
- Use the one-command local scripts as a fallback while you set up Aspire.

## Config
- DAB_GRAPHQL_URL: e.g. http://localhost:8082/graphql

## Switch Data Source
- Leave DAB_GRAPHQL_URL empty to use in-memory data
- Set DAB_GRAPHQL_URL to use GraphQL

## CRUD
- Tenants, Cells, and Operations pages support create/update/delete when GraphQL is enabled (DAB provides mutations).
- For in-memory mode, operations affect only the running process.

## Smoke test (GraphQL)

After starting the local stack, run a minimal CRUD test against DAB:

- pwsh -File .\scripts\graphql-smoke-test.ps1 -AsAdmin

The script lists tenants, creates a temporary tenant, and deletes it (using partitionKeyValue = tenantId). Use -AsAdmin to simulate the `platform.admin` role via X-MS-CLIENT-PRINCIPAL.
