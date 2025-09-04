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

- Start (legacy script removed): the previous helper `scripts/run-local.ps1` has been removed as it was out-of-date.
  Use the portal's modern local startup: `dotnet run --project ./management-portal/src/Portal/Portal.csproj` and run the seeder with `dotnet run --project ./management-portal/Seeder/Seeder.csproj` as needed.
- Stop: pwsh -File .\scripts\stop-local.ps1
- Portal: <http://localhost:8081>
- GraphQL: <http://localhost:8082/graphql>
- Cosmos Emulator: <https://localhost:8085>

Local Run (AppHost)

- Build AppHost: dotnet build management-portal/AppHost
- Run AppHost: dotnet run --project management-portal/AppHost
- Portal URL: <http://localhost:8081>

Note: AppHost is no longer dependent on the .NET Aspire runtime for local runs. The portal hosts a built-in Hot Chocolate GraphQL endpoint and local scripts now rely on that endpoint.

Troubleshooting

- If you encounter issues running the portal locally, run the portal directly with `dotnet run --project ./management-portal/src/Portal/Portal.csproj` and follow the guidance in `docs/DEVELOPER_QUICKSTART.md` for emulator seeding and cert trust. The old one-command helper was removed because it referenced deleted DAB code.

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
