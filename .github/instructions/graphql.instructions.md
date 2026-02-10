# GraphQL — Instructions

applyTo: "management-portal/src/Portal/GraphQL/**/*.cs,management-portal/src/Portal/Services/**/*.cs"

## GraphQL Backend

The management portal uses **Hot Chocolate** as the GraphQL server framework. This is the current, actively supported stack — do not introduce other GraphQL libraries (e.g., GraphQL.NET, Strawberry Shake server-side).

### Endpoint

- GraphQL endpoint: `/graphql`
- Configuration env var: `GRAPHQL_URL` (default: `http://localhost:5000/graphql` for local dev)

### Architecture

```
Blazor Pages → GraphQL Client → Hot Chocolate Server → Cosmos DB / Azure Services
```

- Hot Chocolate serves as the API layer between the Blazor frontend and backend data stores
- Resolvers fetch data from the global Cosmos DB (`globaldb`) for tenant and CELL data
- The GraphQL backend runs in the same process as the Blazor Server app

### Code Organization

| Path | Purpose |
|------|---------|
| `Portal/GraphQL/` | Query types, mutation types, subscriptions, input types |
| `Portal/Models/` | Data transfer objects shared between GraphQL and services |
| `Portal/Services/` | Data access services injected into resolvers |

### Hot Chocolate Conventions

- Define query types as classes with `[QueryType]` or registered via `AddQueryType<T>()`
- Use descriptive resolver method names: `GetTenants()`, `GetCellsByRegion(string region)`
- Mutations should return the modified object for client cache updates
- Use `[GraphQLDescription("...")]` on all public types and fields
- Use DataLoader pattern for batched/cached data access (avoid N+1 queries)

### Error Handling in GraphQL

- Use Hot Chocolate's error filter for consistent error responses
- Map `CosmosException` (404) to GraphQL `NOT_FOUND` error codes
- Never expose internal stack traces in GraphQL error extensions
- Log full errors server-side, return sanitized messages to clients

### Data Source

- Primary data: Cosmos DB `globaldb` (tenants, cells containers)
- Discovery data: Azure Resource Manager via `DefaultAzureCredential`
- Cached discovery results via `DiscoveryCacheService`

### Local Development

```json
// appsettings.json (development)
{
  "GraphQL": {
    "Endpoint": "http://localhost:5000/graphql"
  }
}
```

- Hot Chocolate Banana Cake Pop (built-in IDE) available at `/graphql` in dev mode
- Use it for testing queries and exploring the schema

### Testing GraphQL

- Test resolvers independently by mocking service dependencies
- Use integration tests with `WebApplicationFactory` for full pipeline testing
- Verify schema changes don't break existing client queries
