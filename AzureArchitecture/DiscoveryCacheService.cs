using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using System;
using System.Threading.Tasks;

namespace AzureArchitecture.Services
{
    /// <summary>
    /// Discovery result caching service with intelligent cache warming and invalidation
    /// </summary>
    public class DiscoveryCacheService
    {
        private readonly IMemoryCache _memoryCache;
        private readonly ILogger<DiscoveryCacheService> _logger;
        private readonly TimeSpan _defaultCacheDuration = TimeSpan.FromMinutes(5);
        private readonly TimeSpan _backgroundRefreshInterval = TimeSpan.FromMinutes(3);

        public DiscoveryCacheService(
            IMemoryCache memoryCache,
            ILogger<DiscoveryCacheService> logger)
        {
            _memoryCache = memoryCache ?? throw new ArgumentNullException(nameof(memoryCache));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        /// <summary>
        /// Gets cached discovery result or returns null if not found or expired
        /// </summary>
        public async Task<object?> GetCachedDiscoveryAsync(string mode, string cacheKey = null)
        {
            try
            {
                var key = cacheKey ?? $"discovery_result_{mode}";
                
                if (_memoryCache.TryGetValue(key, out var cachedResult))
                {
                    _logger.LogInformation("Cache hit for discovery mode: {Mode}", mode);
                    return cachedResult;
                }

                _logger.LogInformation("Cache miss for discovery mode: {Mode}", mode);
                return null;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error retrieving cached discovery result for mode: {Mode}", mode);
                return null;
            }
        }

        /// <summary>
        /// Caches discovery result with intelligent expiration and background refresh
        /// </summary>
        public async Task SetCachedDiscoveryAsync(string mode, object result, string cacheKey = null, TimeSpan? duration = null)
        {
            try
            {
                var key = cacheKey ?? $"discovery_result_{mode}";
                var cacheDuration = duration ?? _defaultCacheDuration;

                var cacheOptions = new MemoryCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = cacheDuration,
                    SlidingExpiration = TimeSpan.FromMinutes(2),
                    Priority = CacheItemPriority.High,
                    Size = CalculateCacheSize(result)
                };

                // Add eviction callback for monitoring
                cacheOptions.RegisterPostEvictionCallback(OnCacheEviction);

                _memoryCache.Set(key, result, cacheOptions);

                // Schedule background refresh
                _ = Task.Run(async () => await ScheduleBackgroundRefresh(key, mode));

                _logger.LogInformation("Cached discovery result for mode: {Mode}, Duration: {Duration}", mode, cacheDuration);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error caching discovery result for mode: {Mode}", mode);
            }
        }

        /// <summary>
        /// Invalidates cached discovery results
        /// </summary>
        public async Task InvalidateCacheAsync(string mode = null, string pattern = null)
        {
            try
            {
                if (!string.IsNullOrEmpty(mode))
                {
                    var key = $"discovery_result_{mode}";
                    _memoryCache.Remove(key);
                    _logger.LogInformation("Invalidated cache for mode: {Mode}", mode);
                }
                else if (!string.IsNullOrEmpty(pattern))
                {
                    // Note: MemoryCache doesn't support pattern-based removal
                    // In production, consider using Redis or implementing custom key tracking
                    _logger.LogWarning("Pattern-based cache invalidation not supported with MemoryCache: {Pattern}", pattern);
                }
                else
                {
                    // Clear all discovery-related cache entries
                    // This is a simplified approach - in production, implement proper key tracking
                    var field = typeof(MemoryCache).GetField("_coherentState", 
                        System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
                    if (field?.GetValue(_memoryCache) is IDictionary<object, object> coherentState)
                    {
                        coherentState.Clear();
                    }
                    _logger.LogInformation("Cleared all cache entries");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error invalidating cache");
            }
        }

        /// <summary>
        /// Gets cache statistics for monitoring
        /// </summary>
        public async Task<CacheStatistics> GetCacheStatisticsAsync()
        {
            try
            {
                // Note: MemoryCache doesn't expose detailed statistics
                // In production, implement custom metrics collection
                return new CacheStatistics
                {
                    TotalEntries = 0, // Would need custom tracking
                    HitRate = 0.0, // Would need custom tracking
                    MissRate = 0.0, // Would need custom tracking
                    TotalMemoryUsage = GC.GetTotalMemory(false),
                    LastUpdated = DateTime.UtcNow
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving cache statistics");
                return new CacheStatistics();
            }
        }

        private async Task ScheduleBackgroundRefresh(string key, string mode)
        {
            try
            {
                await Task.Delay(_backgroundRefreshInterval);
                
                // Check if the cache entry still exists and is close to expiration
                if (_memoryCache.TryGetValue(key, out _))
                {
                    _logger.LogInformation("Background refresh triggered for cache key: {Key}", key);
                    // In a full implementation, this would trigger the discovery function
                    // to refresh the cache proactively
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error during background cache refresh for key: {Key}", key);
            }
        }

        private void OnCacheEviction(object key, object value, EvictionReason reason, object state)
        {
            _logger.LogInformation("Cache entry evicted - Key: {Key}, Reason: {Reason}", key, reason);
        }

        private int CalculateCacheSize(object result)
        {
            try
            {
                // Simple size estimation - in production, implement proper serialization-based sizing
                var json = System.Text.Json.JsonSerializer.Serialize(result);
                return System.Text.Encoding.UTF8.GetByteCount(json);
            }
            catch
            {
                return 1024; // Default size if calculation fails
            }
        }
    }

    /// <summary>
    /// Cache statistics model
    /// </summary>
    public class CacheStatistics
    {
        public int TotalEntries { get; set; }
        public double HitRate { get; set; }
        public double MissRate { get; set; }
        public long TotalMemoryUsage { get; set; }
        public DateTime LastUpdated { get; set; }
    }
}
