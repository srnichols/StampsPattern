# Management Portal


Run locally with one command or via the AppHost. By default, the portal uses in-memory data. For live data, it connects to the built-in Hot Chocolate GraphQL endpoint, which provides full CRUD for Cosmos DB entities.

## Auth and roles (production)

**Hosting**: Azure Container Apps (ACA) for the portal and Hot Chocolate GraphQL API; Azure Functions for command handlers
**Authentication**: Azure Entra ID with OpenID Connect for administrative access
**Authorization**: Uses AppService-compatible headers from Container Apps authentication
- **Portal Roles**:
  - `authenticated` (read access to tenant data)
  - `platform.admin` (full CRUD access)
  - `operator` (read/write for tenant operations)
- **Setup Requirements**:
  - Azure AD app registration with redirect URIs configured
  - Client secret stored in Container App secrets
  - ID tokens enabled in app registration
  - Role mapping through Azure AD groups

For detailed authentication setup, see the main documentation: [DEPLOYMENT_GUIDE.md](../docs/DEPLOYMENT_GUIDE.md#management-portal-authentication-setup)

## Local Run (one command)

- Start: pwsh -File .\scripts\run-local.ps1
- Stop: pwsh -File .\scripts\stop-local.ps1
- Portal: <http://localhost:8081>
- GraphQL: <http://localhost:8082/graphql>
- Cosmos Emulator: <https://localhost:8085>

## Local Run (AppHost)

- Build AppHost: dotnet build management-portal/AppHost
- Run AppHost: dotnet run --project management-portal/AppHost
- Portal URL: <http://localhost:8081>

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


## GraphQL Endpoint

- Hot Chocolate GraphQL endpoint: <http://localhost:8082/graphql>

## Switch Data Source


By default, the portal uses in-memory data. When running in production or with Cosmos DB, the portal uses the built-in Hot Chocolate GraphQL API for all data operations.

## CRUD


Tenants, Cells, and Operations pages support create/update/delete via the Hot Chocolate GraphQL API. In in-memory mode, operations affect only the running process.

## Smoke test (GraphQL)


After starting the local stack, you can run a minimal CRUD test against the Hot Chocolate GraphQL endpoint using your favorite GraphQL client (e.g., Banana Cake Pop, Insomnia, Postman, or curl). Example mutation:

```
mutation {
  createTenant(input: { id: "t1", displayName: "Test Tenant", domain: "test.com", tier: "Standard", status: "Active", cellId: "cell1", contactName: "Jane Doe", contactEmail: "jane@example.com" }) {
    id
    displayName
  }
}
```

You can also use the built-in Banana Cake Pop GraphQL IDE at <http://localhost:8082/graphql> for interactive queries and mutations.
