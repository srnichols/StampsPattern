# Management Portal (Blazor) — Instructions

applyTo: "management-portal/**/*.cs,management-portal/**/*.razor,management-portal/**/*.json"

## Technology Stack

- **Blazor Server** (.NET) — `management-portal/src/Portal/`
- **Hot Chocolate** GraphQL backend — this is the current, supported stack
- **Docker** container deployment to **Azure Container Apps**
- **Azure Developer CLI** (`azd`) for deployment (see `azure.yaml` at repo root)

## Project Structure

| Path | Purpose |
|------|---------|
| `Portal/Program.cs` | Host configuration and service registration |
| `Portal/Pages/` | Blazor page components |
| `Portal/Shared/` | Shared Blazor layout components |
| `Portal/GraphQL/` | Hot Chocolate GraphQL types, queries, mutations |
| `Portal/Models/` | Data models |
| `Portal/Services/` | Business logic and data access services |
| `Portal/wwwroot/` | Static assets (CSS, JS, images) |
| `Portal/Dockerfile` | Container build definition |

## GraphQL Backend

- Use **Hot Chocolate** for all GraphQL endpoints — do not introduce other GraphQL libraries
- GraphQL endpoint: `/graphql`
- Client queries tenant and CELL data from Cosmos DB via Hot Chocolate resolvers
- The portal connects to the same global Cosmos DB (`globaldb`) as the Functions layer

## Configuration

- `appsettings.json` for non-sensitive settings
- `appsettings.Production.json` for production overrides
- Use Azure Key Vault references for secrets in Container Apps
- Environment variable: `GRAPHQL_URL` for the GraphQL backend endpoint

## Deployment

- The portal deploys via `azd up` using the `azure.yaml` at repo root
- Docker image pushed to Azure Container Registry (ACR)
- Container Apps infrastructure defined in `management-portal/infra/`
- Deployment scripts: `management-portal/deploy-container-apps.ps1`

## Seeder

- The `management-portal/Seeder/` project seeds demo/baseline data into Cosmos DB
- Seeder uses `DefaultAzureCredential` — grant the running principal the Cosmos DB Built-in Data Contributor role
- Used for development and integration testing with representative data
