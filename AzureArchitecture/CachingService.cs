using System;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;
using AzureStampsPattern.Models;

namespace AzureStampsPattern.Services
{
    /// <summary>
    /// Caching service for tenant routing information to reduce database hits
    /// </summary>
    public interface ITenantCacheService
    {
        Task<CachedTenantRouting> GetTenantRoutingAsync(string tenantId);
        Task SetTenantRoutingAsync(string tenantId, CachedTenantRouting routing);
        Task InvalidateTenantRoutingAsync(string tenantId);
        Task<CellInfo> GetCellInfoAsync(string cellId);
        Task SetCellInfoAsync(string cellId, CellInfo cellInfo);
        Task InvalidateCellInfoAsync(string cellId);
    }

    /// <summary>
    /// Redis-based implementation of tenant caching service
    /// </summary>
    public class RedisTenantCacheService : ITenantCacheService
    {
        private readonly IDistributedCache _cache;
        private readonly ILogger<RedisTenantCacheService> _logger;
        
        private static readonly TimeSpan DefaultTenantCacheExpiry = TimeSpan.FromHours(1);
        private static readonly TimeSpan DefaultCellCacheExpiry = TimeSpan.FromMinutes(30);

        public RedisTenantCacheService(IDistributedCache cache, ILogger<RedisTenantCacheService> logger)
        {
            _cache = cache ?? throw new ArgumentNullException(nameof(cache));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task<CachedTenantRouting> GetTenantRoutingAsync(string tenantId)
        {
            try
            {
                var cacheKey = GetTenantCacheKey(tenantId);
                var cachedData = await _cache.GetStringAsync(cacheKey);
                
                if (string.IsNullOrEmpty(cachedData))
                {
                    _logger.LogDebug("Cache miss for tenant {TenantId}", tenantId);
                    return null;
                }

                var routing = JsonSerializer.Deserialize<CachedTenantRouting>(cachedData);
                _logger.LogDebug("Cache hit for tenant {TenantId}", tenantId);
                return routing;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving tenant routing from cache for {TenantId}", tenantId);
                return null; // Fail gracefully, fall back to database
            }
        }

        public async Task SetTenantRoutingAsync(string tenantId, CachedTenantRouting routing)
        {
            try
            {
                var cacheKey = GetTenantCacheKey(tenantId);
                var serializedData = JsonSerializer.Serialize(routing);
                
                var options = new DistributedCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = routing.CacheExpiry
                };

                await _cache.SetStringAsync(cacheKey, serializedData, options);
                _logger.LogDebug("Cached tenant routing for {TenantId}", tenantId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error caching tenant routing for {TenantId}", tenantId);
                // Don't throw - caching is not critical
            }
        }

        public async Task InvalidateTenantRoutingAsync(string tenantId)
        {
            try
            {
                var cacheKey = GetTenantCacheKey(tenantId);
                await _cache.RemoveAsync(cacheKey);
                _logger.LogDebug("Invalidated cache for tenant {TenantId}", tenantId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error invalidating cache for tenant {TenantId}", tenantId);
            }
        }

        public async Task<CellInfo> GetCellInfoAsync(string cellId)
        {
            try
            {
                var cacheKey = GetCellCacheKey(cellId);
                var cachedData = await _cache.GetStringAsync(cacheKey);
                
                if (string.IsNullOrEmpty(cachedData))
                {
                    _logger.LogDebug("Cache miss for cell {CellId}", cellId);
                    return null;
                }

                var cellInfo = JsonSerializer.Deserialize<CellInfo>(cachedData);
                _logger.LogDebug("Cache hit for cell {CellId}", cellId);
                return cellInfo;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving cell info from cache for {CellId}", cellId);
                return null;
            }
        }

        public async Task SetCellInfoAsync(string cellId, CellInfo cellInfo)
        {
            try
            {
                var cacheKey = GetCellCacheKey(cellId);
                var serializedData = JsonSerializer.Serialize(cellInfo);
                
                var options = new DistributedCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = DefaultCellCacheExpiry
                };

                await _cache.SetStringAsync(cacheKey, serializedData, options);
                _logger.LogDebug("Cached cell info for {CellId}", cellId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error caching cell info for {CellId}", cellId);
            }
        }

        public async Task InvalidateCellInfoAsync(string cellId)
        {
            try
            {
                var cacheKey = GetCellCacheKey(cellId);
                await _cache.RemoveAsync(cacheKey);
                _logger.LogDebug("Invalidated cache for cell {CellId}", cellId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error invalidating cache for cell {CellId}", cellId);
            }
        }

        private static string GetTenantCacheKey(string tenantId) => $"tenant:routing:{tenantId}";
        private static string GetCellCacheKey(string cellId) => $"cell:info:{cellId}";
    }

    /// <summary>
    /// Enhanced GetTenantCellFunction with caching support
    /// </summary>
    public class CachedGetTenantCellFunction
    {
        private readonly CosmosClient _cosmosClient;
        private readonly Container _tenantsContainer;
        private readonly ITenantCacheService _cacheService;
        private readonly ILogger<CachedGetTenantCellFunction> _logger;

        public CachedGetTenantCellFunction(
            CosmosClient cosmosClient, 
            ITenantCacheService cacheService,
            ILogger<CachedGetTenantCellFunction> logger)
        {
            _cosmosClient = cosmosClient ?? throw new ArgumentNullException(nameof(cosmosClient));
            _cacheService = cacheService ?? throw new ArgumentNullException(nameof(cacheService));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            
            string databaseName = Environment.GetEnvironmentVariable("CosmosDbDatabaseName") ?? "globaldb";
            string tenantsContainerName = Environment.GetEnvironmentVariable("TenantsContainerName") ?? "tenants";
            
            _tenantsContainer = _cosmosClient.GetContainer(databaseName, tenantsContainerName);
        }

        [Function("GetTenantCellCached")]
        public async Task<HttpResponseData> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "tenant/{tenantId}/cell")] HttpRequestData req,
            string tenantId)
        {
            try
            {
                _logger.LogInformation("Getting CELL information for tenant {TenantId}", tenantId);

                // Try cache first
                var cachedRouting = await _cacheService.GetTenantRoutingAsync(tenantId);
                if (cachedRouting != null)
                {
                    var cachedResponse = req.CreateResponse(HttpStatusCode.OK);
                    await cachedResponse.WriteAsJsonAsync(new
                    {
                        tenantId = cachedRouting.TenantId,
                        cellBackendPool = cachedRouting.CellBackendPool,
                        region = cachedRouting.Region,
                        subdomain = cachedRouting.Subdomain,
                        tenantTier = cachedRouting.TenantTier.ToString(),
                        source = "cache"
                    });
                    return cachedResponse;
                }

                // Cache miss - get from database
                var tenant = await _tenantsContainer.ReadItemAsync<TenantInfo>(tenantId, new PartitionKey(tenantId));
                
                // Cache the result
                var routing = new CachedTenantRouting
                {
                    TenantId = tenant.Resource.tenantId,
                    CellBackendPool = tenant.Resource.cellBackendPool,
                    Region = tenant.Resource.region,
                    Subdomain = tenant.Resource.subdomain,
                    TenantTier = tenant.Resource.tenantTier ?? TenantTier.Shared,
                    LastModified = tenant.Resource.lastModifiedDate ?? tenant.Resource.createdDate
                };

                await _cacheService.SetTenantRoutingAsync(tenantId, routing);

                var response = req.CreateResponse(HttpStatusCode.OK);
                await response.WriteAsJsonAsync(new
                {
                    tenantId = routing.TenantId,
                    cellBackendPool = routing.CellBackendPool,
                    region = routing.Region,
                    subdomain = routing.Subdomain,
                    tenantTier = routing.TenantTier.ToString(),
                    source = "database"
                });
                return response;
            }
            catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
            {
                _logger.LogWarning("Tenant {TenantId} not found", tenantId);
                var notFoundResponse = req.CreateResponse(HttpStatusCode.NotFound);
                await notFoundResponse.WriteStringAsync("Tenant not found.");
                return notFoundResponse;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving CELL information for tenant {TenantId}", tenantId);
                var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
                await errorResponse.WriteStringAsync("An error occurred while retrieving tenant information.");
                return errorResponse;
            }
        }
    }
}
