# Caching — Instructions

applyTo: "AzureArchitecture/CachingService.cs,AzureArchitecture/DiscoveryCacheService.cs,AzureArchitecture/Program.cs"

## Caching Architecture

The solution uses a **two-tier caching strategy** with Redis for production and in-memory for development.

### Interface: `ITenantCacheService`

```csharp
public interface ITenantCacheService
{
    Task<CachedTenantRouting> GetTenantRoutingAsync(string tenantId);
    Task SetTenantRoutingAsync(string tenantId, CachedTenantRouting routing);
    Task InvalidateTenantRoutingAsync(string tenantId);
    Task<CellInfo> GetCellInfoAsync(string cellId);
    Task SetCellInfoAsync(string cellId, CellInfo cellInfo);
    Task InvalidateCellInfoAsync(string cellId);
}
```

### Implementations

| Implementation | Backing Store | Registration | Use Case |
|----------------|---------------|--------------|----------|
| `RedisTenantCacheService` | `IDistributedCache` (StackExchange.Redis) | When `RedisConnection` env var is set | Production |
| `MemoryTenantCacheService` | `IMemoryCache` | Fallback when Redis unavailable | Development/Testing |

### Cache Key Patterns

- Tenant routing: `tenant:routing:{tenantId}`
- Cell info: `cell:info:{cellId}`
- Discovery results: `discovery_result_{mode}` (mode: `azure` or `simulated`)

### TTL (Time-to-Live) Defaults

| Data Type | TTL | Rationale |
|-----------|-----|-----------|
| Tenant routing | 1 hour | Routing rarely changes; invalidated on migration |
| Cell info | 30 minutes | CELL status can change with capacity events |
| Discovery results | 5 minutes | Infrastructure state changes infrequently |
| JWKS configuration | 24 hours | Signing keys rotate infrequently |

### Discovery Cache (`DiscoveryCacheService`)

- Uses `IMemoryCache` with:
  - `AbsoluteExpirationRelativeToNow` for hard TTL
  - `SlidingExpiration` (2 minutes) for frequently accessed items
  - `Priority = High` to resist eviction
  - `Size` estimation for bounded cache
- Post-eviction callbacks for monitoring
- Background refresh scheduling (3-minute intervals)

### Cache Failure Handling (Critical Pattern)

**Caching is never critical path.** All cache operations must:

1. **Catch all exceptions** — never let cache failures propagate
2. **Log the error** — `_logger.LogError(ex, "Error retrieving/caching...")`
3. **Return null/continue** — fall back to the database
4. **Never throw** from Set/Invalidate operations

```csharp
// CORRECT pattern
public async Task<CachedTenantRouting> GetTenantRoutingAsync(string tenantId)
{
    try
    {
        var cached = await _cache.GetStringAsync(key);
        if (string.IsNullOrEmpty(cached)) return null; // cache miss
        return JsonSerializer.Deserialize<CachedTenantRouting>(cached);
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Cache error for {TenantId}", tenantId);
        return null; // graceful degradation
    }
}
```

### Cache Invalidation Triggers

- Tenant migration (Shared → Dedicated)
- CELL reassignment
- Tenant status change
- Manual cache flush via API

### DI Registration (Program.cs)

```csharp
var redisConnection = Environment.GetEnvironmentVariable("RedisConnection");
if (!string.IsNullOrEmpty(redisConnection))
{
    services.AddStackExchangeRedisCache(options => {
        options.Configuration = redisConnection;
        options.InstanceName = "StampsPattern";
    });
    services.AddScoped<ITenantCacheService, RedisTenantCacheService>();
}
else
{
    services.AddMemoryCache();
    services.AddScoped<ITenantCacheService, MemoryTenantCacheService>();
}
```

### Monitoring

- Enhanced monitoring Bicep (`enhancedMonitoring.bicep`) includes Redis cache hit ratio alerts
- Alert when cache hit ratio drops below 80%
- Alert on high cache memory usage and connection failures
