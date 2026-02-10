# Database — Instructions

applyTo: "AzureArchitecture/**/*.cs,AzureArchitecture/cosmos-indexing-policy.json,AzureArchitecture/deploymentStampLayer.bicep,AzureArchitecture/globalLayer.bicep"

## Azure Cosmos DB (Global Control Plane)

### Configuration

- Database name: `globaldb` (env var: `CosmosDbDatabaseName`)
- Containers:
  - `tenants` — partition key: `/tenantId` (env var: `TenantsContainerName`)
  - `cells` — partition key: `/cellId` (env var: `CellsContainerName`)
  - `tenantUsers` — partition key: `/tenantId` (env var: `CosmosDbUserContainerName`)
- Consistency level: **Session** (balance of performance and consistency)
- Connection mode: **Direct** (better performance than Gateway)
- Indexing policy: defined in `cosmos-indexing-policy.json`

### Client Configuration

```csharp
var cosmosClientOptions = new CosmosClientOptions
{
    ApplicationName = "AzureStampsPattern",
    MaxRetryAttemptsOnRateLimitedRequests = 3,
    MaxRetryWaitTimeOnRateLimitedRequests = TimeSpan.FromSeconds(30),
    ConnectionMode = ConnectionMode.Direct,
    ConsistencyLevel = ConsistencyLevel.Session
};
```

- Register `CosmosClient` as **Singleton** in DI (expensive to create)
- Get containers via `_cosmosClient.GetContainer(databaseName, containerName)`

### Query Patterns

**Always use parameterized queries:**

```csharp
// CORRECT — parameterized
var query = new QueryDefinition("SELECT * FROM c WHERE c.region = @region AND c.status = @status")
    .WithParameter("@region", region)
    .WithParameter("@status", CellStatus.Active.ToString());

// NEVER — string interpolation
var query = $"SELECT * FROM c WHERE c.region = '{region}'"; // SQL injection risk
```

**Iterator pattern:**

```csharp
var items = new List<T>();
var iterator = container.GetItemQueryIterator<T>(queryDefinition);
while (iterator.HasMoreResults)
{
    var response = await iterator.ReadNextAsync();
    items.AddRange(response);
}
```

**Point reads (prefer when you have partition key + id):**

```csharp
var response = await container.ReadItemAsync<TenantInfo>(tenantId, new PartitionKey(tenantId));
```

### Write Patterns

```csharp
// Create
await container.CreateItemAsync(item, new PartitionKey(item.tenantId));

// Update (replace)
await container.ReplaceItemAsync(item, item.tenantId, new PartitionKey(item.tenantId));
```

### Error Handling

- Catch `CosmosException` and check `StatusCode`:
  - `HttpStatusCode.NotFound` (404) — item doesn't exist
  - `HttpStatusCode.Conflict` (409) — duplicate item
  - `HttpStatusCode.TooManyRequests` (429) — rate limited (auto-retried by client)
- On rate limiting: the SDK auto-retries up to 3 times with exponential backoff
- Always wrap DB operations in try/catch; return appropriate HTTP status codes

### Cosmos DB Infrastructure (Bicep)

- Global control plane Cosmos DB deployed in `geodesLayer.bicep`
- Zone redundancy: `cosmosZoneRedundant` = true in prod, false otherwise
- Multi-region replication via `additionalLocations` parameter
- Per-CELL Cosmos DB accounts supported (deployed in `deploymentStampLayer.bicep`)
- Connection string stored in Key Vault via deployment script with retry logic

## Azure SQL (Per-CELL Data)

- Each CELL has its own Azure SQL Server and database
- SKU: `S0` for non-prod, `S1` for prod (configurable: `sqlDatabaseSkuTier`, `sqlDatabaseSkuName`)
- Admin credentials passed via `@secure()` parameters
- Private endpoints available per CELL

## Data Residency

- Tenant `dataResidencyRequirements` field stores required regions
- CELL assignment respects `region` parameter
- Cosmos DB replication configured per deployment topology
- Data never crosses compliance boundaries without explicit configuration
