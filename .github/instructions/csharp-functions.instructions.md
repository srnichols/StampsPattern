# C# & Azure Functions — Coding Instructions

applyTo: "AzureArchitecture/**/*.cs"

## Runtime & Framework

- Target framework: **.NET 6** (`net6.0`)
- Azure Functions **v4** with **isolated worker model** (`dotnet-isolated`)
- Entry point: `Program.cs` using `HostBuilder.ConfigureFunctionsWorkerDefaults()`
- `ImplicitUsings` and `Nullable` are enabled in the project

## Namespaces

- Functions and models: `AzureStampsPattern` or `AzureStampsPattern.Models` or `AzureStampsPattern.Functions`
- Services: `AzureStampsPattern.Services` or `AzureArchitecture.Services`
- Keep new code in the appropriate existing namespace

## Dependency Injection

- All new services must be registered in `Program.ConfigureServices()`
- Functions should accept dependencies via **constructor injection** (CosmosClient, ILogger<T>, ITenantCacheService, etc.)
- Fallback parameterless constructors exist for legacy compat — always prefer DI constructors for new code
- `CosmosClient` is registered as **Singleton**
- Cache services and function classes registered as **Scoped**

## Cosmos DB Patterns

- Use parameterized queries with `QueryDefinition` and `.WithParameter()` — never string-interpolate user input
- Database name from env: `CosmosDbDatabaseName` (default `globaldb`)
- Container names from env: `TenantsContainerName` (default `tenants`), `CellsContainerName` (default `cells`)
- Partition key: `tenantId` for tenants, `cellId` for cells
- Use `CosmosClientOptions` with `ConnectionMode.Direct` and `ConsistencyLevel.Session`
- Max retry: 3 attempts, 30s wait for rate-limited requests

## Caching Strategy

- Interface: `ITenantCacheService` with Get/Set/Invalidate methods for tenant routing and cell info
- Production: `RedisTenantCacheService` using `IDistributedCache` (StackExchange.Redis)
- Development fallback: `MemoryTenantCacheService` using `IMemoryCache`
- Default cache TTL: 1 hour for tenant routing, 30 minutes for cell info
- Cache failures must be handled gracefully (log and continue, never throw)

## HTTP Functions

- Use `AuthorizationLevel.Function` for all operational endpoints
- Use `AuthorizationLevel.Anonymous` only for health checks and documentation endpoints
- Route prefix: `api/` (configured in host.json)
- Route patterns: `tenant/{tenantId}`, `tenant/{subdomain}`, `cells/capacity`, `cells/provision`, `cells/analytics`
- Always return proper HTTP status codes (201 Created, 400 BadRequest, 404 NotFound, 500 InternalServerError)
- Use `req.ReadFromJsonAsync<T>()` for request deserialization
- Use `response.WriteAsJsonAsync()` for response serialization

## Authentication

- JWT validation via Microsoft Entra External ID (customers, formerly Azure AD B2C)
- JWKS keys are cached in a `MemoryCache` to avoid repeated discovery calls
- Auth config env vars: `EXTERNAL_ID_TENANT`, `EXTERNAL_ID_CLIENT_ID`, `EXTERNAL_ID_USER_FLOW`
- B2C fallback env vars: `B2C_TENANT`, `B2C_CLIENT_ID`, `B2C_POLICY`

## JSON Serialization

- Use `System.Text.Json` throughout — **do not** add Newtonsoft.Json
- Use `JsonNamingPolicy.CamelCase` for API responses
- Use `WriteIndented = true` only for documentation/debug endpoints

## Error Handling

- Wrap function bodies in try/catch
- Catch `JsonException` for invalid request payloads → return 400
- Catch `CosmosException` for database errors → check `StatusCode` for 404 vs 500
- Always log errors with structured logging: `_logger.LogError(ex, "Message {Param}", value)`
- Use structured log templates (not string interpolation) for ILogger calls

## Logging

- Use `ILogger<T>` injected via constructor — never use `Console.WriteLine` for new code
- Log levels: `Information` for operations, `Warning` for validation failures, `Error` for exceptions, `Debug` for cache hits/misses

## Code Style

- Use file-scoped namespaces where possible for new files
- Use `string.Empty` instead of `""`
- Use `is null` / `is not null` pattern matching
- Validate constructor parameters with `?? throw new ArgumentNullException()`
- Environment variable reads: `Environment.GetEnvironmentVariable("Name") ?? "default"`
- Include XML documentation comments (`/// <summary>`) on all public types and methods
