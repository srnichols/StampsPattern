# Performance — Instructions

applyTo: "AzureArchitecture/PerformanceMonitoringService.cs,AzureArchitecture/CachingService.cs,AzureArchitecture/DiscoveryCacheService.cs,AzureArchitecture/host.json"

## Performance Architecture

The solution targets sub-second API response times under normal load with specific optimizations for multi-tenant workloads.

### Key Performance Targets

| Metric | Target | Mechanism |
|--------|--------|-----------|
| Tenant routing lookup | <50ms (cached), <200ms (DB) | Redis/memory cache with 1-hour TTL |
| JWT validation | <10ms (cached JWKS), <500ms (cold) | 24-hour JWKS cache, 85-90% improvement |
| Cosmos DB point reads | <10ms (same region) | Direct connection mode, Session consistency |
| Infrastructure discovery | <500ms (cached), <5s (live) | 5-minute result cache with background refresh |
| CELL capacity analytics | <1s | Aggregated queries with result caching |

### Cosmos DB Performance

- **Connection mode: Direct** — bypasses gateway for lower latency
- **Consistency: Session** — balances performance with read-your-writes guarantee
- **Point reads over queries** — use `ReadItemAsync(id, partitionKey)` when possible
- **Partition key alignment** — `tenantId` or `cellId` ensures single-partition queries
- **SDK retry**: 3 attempts with 30s max wait handles transient rate limiting

### Caching Performance

- **Redis** (production): distributed, shared across Function instances
  - Instance name prefix: `StampsPattern`
  - TTL: 1 hour for routing, 30 minutes for CELL info
- **Memory cache** (development): per-instance, zero network overhead
  - Sliding expiration: 2 minutes for frequently accessed items
  - Cache size limits to prevent memory pressure
- **Background refresh**: discovery cache refreshes 2 minutes before expiry

### Concurrency

```json
{
  "concurrency": {
    "dynamicConcurrencyEnabled": true,
    "snapshotPersistenceEnabled": true
  },
  "extensions": {
    "http": {
      "maxOutstandingRequests": 200,
      "maxConcurrentRequests": 100,
      "dynamicThrottlesEnabled": true
    }
  }
}
```

- Dynamic concurrency auto-tunes based on host health
- Snapshot persistence prevents cold-start performance regression
- Dynamic throttles prevent overload on individual instances

### PerformanceMonitoringService

Wrap critical operations to collect metrics:

```csharp
// Async operations
var result = await _performanceService.MeasureAsync("InfrastructureDiscovery", async () => {
    return await DiscoverFromAzure();
});

// Sync operations
var cells = _performanceService.Measure("SimulatedDiscovery", () => GetSimulatedCells());
```

Metrics collected per operation:
- Execution count, success/failure rates
- Min/Max/Average duration in milliseconds
- Error type frequency distribution
- Last execution timestamp

### APIM Rate Limiting

- 1,000 calls per 60 seconds per tenant (keyed on `X-Tenant-ID` header)
- Prevents noisy-neighbor effects in shared CELLs
- Different rate limits can be configured per tenant tier

### Function Timeout

- Default timeout: 5 minutes (`functionTimeout: "00:05:00"`)
- Retry strategy: exponential backoff, 3 retries, 5s to 5-minute intervals
- Health monitor counters ensure unhealthy instances are removed from rotation

### CELL Load Balancing

- Shared CELL assignment selects the CELL with **lowest tenant count**
- Prevents hot-spotting across shared CELLs
- CELL utilization metrics: CPU, memory, storage, network tracked in `CellInfo`
- Auto-scaling enabled by default for Container Apps environments

### Performance Anti-Patterns to Avoid

1. **Don't create CosmosClient per request** — it's an expensive, reusable object (Singleton)
2. **Don't skip caching for hot paths** — tenant routing is called on every request
3. **Don't use `Console.WriteLine`** — use `ILogger` for proper handler integration
4. **Don't use `Gateway` connection mode** — `Direct` is faster for Cosmos DB
5. **Don't use `Strong` consistency** — `Session` is sufficient and much faster
6. **Don't make cache failures fatal** — always degrade gracefully
7. **Don't iterate all items** — use partition-aligned queries to avoid cross-partition scans
