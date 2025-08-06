using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Caching.StackExchangeRedis;
using AzureStampsPattern.Services;
using System;

namespace AzureStampsPattern
{
    /// <summary>
    /// Program class for Azure Functions with dependency injection setup
    /// </summary>
    public class Program
    {
        public static void Main()
        {
            var host = new HostBuilder()
                .ConfigureFunctionsWorkerDefaults()
                .ConfigureServices(ConfigureServices)
                .Build();

            host.Run();
        }

        /// <summary>
        /// Configure dependency injection services
        /// </summary>
        private static void ConfigureServices(IServiceCollection services)
        {
            // Cosmos DB Client - Singleton
            services.AddSingleton<CosmosClient>(serviceProvider =>
            {
                var connectionString = Environment.GetEnvironmentVariable("CosmosDbConnection");
                if (string.IsNullOrEmpty(connectionString))
                {
                    throw new InvalidOperationException("CosmosDbConnection environment variable is required");
                }

                var cosmosClientOptions = new CosmosClientOptions
                {
                    ApplicationName = "AzureStampsPattern",
                    MaxRetryAttemptsOnRateLimitedRequests = 3,
                    MaxRetryWaitTimeOnRateLimitedRequests = TimeSpan.FromSeconds(30),
                    ConnectionMode = ConnectionMode.Direct, // Better performance
                    ConsistencyLevel = ConsistencyLevel.Session // Balance of performance and consistency
                };

                return new CosmosClient(connectionString, cosmosClientOptions);
            });

            // Redis Cache - if connection string is provided
            var redisConnectionString = Environment.GetEnvironmentVariable("RedisConnection");
            if (!string.IsNullOrEmpty(redisConnectionString))
            {
                services.AddStackExchangeRedisCache(options =>
                {
                    options.Configuration = redisConnectionString;
                    options.InstanceName = "StampsPattern";
                });
                
                // Register Redis-based cache service
                services.AddScoped<ITenantCacheService, RedisTenantCacheService>();
            }
            else
            {
                // Fallback to in-memory cache
                services.AddMemoryCache();
                services.AddScoped<ITenantCacheService, MemoryTenantCacheService>();
            }

            // Register Function classes for dependency injection
            services.AddScoped<CreateTenantFunction>();
            services.AddScoped<TenantMigrationFunction>();
            services.AddScoped<GetTenantInfoFunction>();
            services.AddScoped<CachedGetTenantCellFunction>();
        }
    }

    /// <summary>
    /// In-memory cache implementation for development/testing
    /// </summary>
    public class MemoryTenantCacheService : ITenantCacheService
    {
        private readonly Microsoft.Extensions.Caching.Memory.IMemoryCache _cache;
        private readonly Microsoft.Extensions.Logging.ILogger<MemoryTenantCacheService> _logger;

        public MemoryTenantCacheService(
            Microsoft.Extensions.Caching.Memory.IMemoryCache cache,
            Microsoft.Extensions.Logging.ILogger<MemoryTenantCacheService> logger)
        {
            _cache = cache;
            _logger = logger;
        }

        public Task<AzureStampsPattern.Models.CachedTenantRouting> GetTenantRoutingAsync(string tenantId)
        {
            _cache.TryGetValue($"tenant:routing:{tenantId}", out AzureStampsPattern.Models.CachedTenantRouting routing);
            return Task.FromResult(routing);
        }

        public Task SetTenantRoutingAsync(string tenantId, AzureStampsPattern.Models.CachedTenantRouting routing)
        {
            _cache.Set($"tenant:routing:{tenantId}", routing, routing.CacheExpiry);
            return Task.CompletedTask;
        }

        public Task InvalidateTenantRoutingAsync(string tenantId)
        {
            _cache.Remove($"tenant:routing:{tenantId}");
            return Task.CompletedTask;
        }

        public Task<AzureStampsPattern.Models.CellInfo> GetCellInfoAsync(string cellId)
        {
            _cache.TryGetValue($"cell:info:{cellId}", out AzureStampsPattern.Models.CellInfo cellInfo);
            return Task.FromResult(cellInfo);
        }

        public Task SetCellInfoAsync(string cellId, AzureStampsPattern.Models.CellInfo cellInfo)
        {
            _cache.Set($"cell:info:{cellId}", cellInfo, TimeSpan.FromMinutes(30));
            return Task.CompletedTask;
        }

        public Task InvalidateCellInfoAsync(string cellId)
        {
            _cache.Remove($"cell:info:{cellId}");
            return Task.CompletedTask;
        }
    }
}
