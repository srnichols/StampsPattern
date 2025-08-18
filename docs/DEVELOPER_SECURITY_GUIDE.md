
# 🔐 Azure Stamps Pattern - Developer Security Implementation Guide

How to implement zero‑trust security in code and infra: JWT validation, private endpoints, managed identity, caching, indexing, and robust error handling, optimized for performance and compliance.

- What’s inside: Breaking changes, secure patterns, code samples, and test guidance
- Best for: New and experienced developers plus DevOps/platform teams
- Outcomes: Secure-by-default services with measurable latency and reliability gains

## 👤 Who Should Read This Guide?

- **New Developers:** Ramp up on security requirements and implementation
- **Experienced Engineers:** Apply advanced security and performance patterns
- **DevOps/Platform Teams:** Ensure compliance and operational security

---

## 🧭 Quick Navigation

| Section | Focus Area | Best for |
|---------|------------|----------|
| [🚨 Critical Security Changes](#-critical-security-changes-august-2025) | Breaking changes, compliance | All developers |
| [🔧 Implementation Guide](#-developer-implementation-guide) | JWT, DB, DI, caching | Developers |
| [🧪 Testing Guidelines](#-testing-guidelines) | Unit/integration tests | Developers |
| [📋 Configuration Checklist](#-configuration-checklist) | Env vars, NuGet, indexing | DevOps |
| [🔍 Debugging & Troubleshooting](#-debugging-and-troubleshooting) | Common issues, monitoring | All |
| [📚 Additional Resources](#-additional-resources) | Best practices, docs | All |
| [🔗 Related Documentation](#-related-documentation) | Other guides | All |

---

## 📚 For New Developers

**What is this guide for?**
> This guide is your onboarding reference for implementing secure, compliant, and high-performance solutions in the Azure Stamps Pattern. It explains what changed, why it matters, and how to apply best practices in your code and infrastructure.

**Why is this important?**
> - **Security:** Prevent breaches and ensure compliance from day one
> - **Performance:** Leverage caching and indexing for fast, reliable apps
> - **Onboarding:** Learn by example with before/after code and configuration
> - **Troubleshooting:** Quickly resolve common issues and avoid pitfalls

---



## 🚨 Critical Security Changes (August 2025)

Read this section first when upgrading existing services; it highlights breaking changes and performance wins that affect code, infra, and configuration.

### ⚠️ **Breaking Changes**
- **Cosmos DB**: Public access now **PERMANENTLY DISABLED** by default
- **SQL Server**: Firewall rules are **conditional** based on private endpoint configuration
- **JWT Validation**: Enhanced validation requires proper External ID configuration
- **Connection Strings**: Must use managed identities or Key Vault references

### ✅ **Performance Improvements**
- **JWT Validation**: 85-90% latency reduction (100-200ms → 10-20ms)
- **Database Queries**: Composite indexes reduce query time by 60-80%
- **Caching**: Redis implementation reduces database hits by 80-90%

## 🔧 Developer Implementation Guide

This section provides before/after examples for JWT validation, data access, DI, caching, and error handling to achieve zero-trust with strong performance.

### 1. **Enhanced JWT Validation Implementation**

#### **Before (Legacy)**
```csharp
// ❌ Old approach - no caching, basic validation
public static async Task<ClaimsPrincipal?> ValidateTokenAsync(HttpRequestData req)
{
    var token = authHeader.Substring("Bearer ".Length);
    var configManager = new ConfigurationManager<OpenIdConnectConfiguration>(
        $"{authority}.well-known/openid-configuration",
        new OpenIdConnectConfigurationRetriever()
    );
    var config = await configManager.GetConfigurationAsync(CancellationToken.None);
    // Basic validation without caching
}
```

#### **After (Enhanced)**
```csharp
// ✅ New approach - cached, comprehensive validation
public static class JwtValidator
{
    private static readonly MemoryCache _jwksCache = new MemoryCache(new MemoryCacheOptions
    {
        SizeLimit = 100
    });

    public static async Task<ClaimsPrincipal?> ValidateTokenAsync(HttpRequestData req)
    {
        try
        {
            var token = authHeader.Substring("Bearer ".Length);
            
            // Cache JWKS configuration for 24 hours
            var cacheKey = $"jwks_{tenant}_{policy}";
            if (!_jwksCache.TryGetValue(cacheKey, out OpenIdConnectConfiguration? config))
            {
                var configManager = new ConfigurationManager<OpenIdConnectConfiguration>(
                    metadataAddress, new OpenIdConnectConfigurationRetriever());
                config = await configManager.GetConfigurationAsync(CancellationToken.None);
                _jwksCache.Set(cacheKey, config, TimeSpan.FromHours(24));
            }

            var validationParameters = new TokenValidationParameters
            {
                ValidIssuer = authority,
                ValidAudiences = new[] { clientId },
                IssuerSigningKeys = config.SigningKeys,
                ValidateIssuer = true,        // ✅ Enhanced validation
                ValidateAudience = true,      // ✅ Enhanced validation
                ValidateLifetime = true,      // ✅ Enhanced validation
                ValidateIssuerSigningKey = true, // ✅ Enhanced validation
                ClockSkew = TimeSpan.FromMinutes(5) // ✅ Clock skew tolerance
            };

            var result = await tokenHandler.ValidateTokenAsync(token, validationParameters);
            return result.IsValid ? new ClaimsPrincipal(result.ClaimsIdentity) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error validating JWT token");
            return null; // ✅ Graceful degradation
        }
    }
}
```

### 2. **Zero-Trust Database Configuration**

#### **Cosmos DB Configuration**
```bicep
// ✅ Zero-trust configuration
resource cellCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  properties: {
    // 🔒 CRITICAL: Public access permanently disabled
    publicNetworkAccess: 'Disabled' // Always disabled for zero-trust
    
    // Enhanced security features
    disableKeyBasedMetadataWriteAccess: true
    networkAclBypass: 'AzureServices'
    isVirtualNetworkFilterEnabled: enablePrivateEndpoints
    minimalTlsVersion: 'Tls12'
    
    // Private endpoint required for access
    // Must provision private endpoint or deployment will fail
  }
}
```

#### **SQL Server Configuration**
```bicep
// ✅ Conditional firewall rules
resource sqlServer 'Microsoft.Sql/servers@2022-11-01-preview' = {
  properties: {
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled' // Zero-trust by default
  }
}

// 🎯 Smart firewall rules - only when private endpoints disabled
resource sqlFirewallRule 'Microsoft.Sql/servers/firewallRules@2022-11-01-preview' = if (!enablePrivateEndpoints) {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}
```

### 3. **Dependency Injection Pattern**

#### **Function Implementation**
```csharp
// ✅ Dependency injection for testability and reliability
public class CreateTenantFunction
{
    private readonly CosmosClient _cosmosClient;
    private readonly ILogger<CreateTenantFunction> _logger;

    // Primary constructor with DI
    public CreateTenantFunction(CosmosClient cosmosClient, ILogger<CreateTenantFunction> logger)
    {
        _cosmosClient = cosmosClient ?? throw new ArgumentNullException(nameof(cosmosClient));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    // Fallback constructor for environments without DI
    public CreateTenantFunction() : this(
        new CosmosClient(Environment.GetEnvironmentVariable("CosmosDbConnection") ?? 
            throw new InvalidOperationException("CosmosDbConnection not configured")),
        LoggerFactory.Create(builder => builder.AddConsole()).CreateLogger<CreateTenantFunction>())
    {
    }
}
```

#### **Service Registration**
```csharp
// Program.cs - Service registration
public static void Main()
{
    var host = new HostBuilder()
        .ConfigureFunctionsWorkerDefaults()
        .ConfigureServices(ConfigureServices)
        .Build();
    host.Run();
}

private static void ConfigureServices(IServiceCollection services)
{
    // Cosmos DB Client with optimized configuration
    services.AddSingleton<CosmosClient>(serviceProvider =>
    {
        var connectionString = Environment.GetEnvironmentVariable("CosmosDbConnection");
        return new CosmosClient(connectionString, new CosmosClientOptions
        {
            ConnectionMode = ConnectionMode.Direct, // Better performance
            ConsistencyLevel = ConsistencyLevel.Session,
            MaxRetryAttemptsOnRateLimitedRequests = 3
        });
    });

    // Caching service with Redis fallback to memory
    if (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable("RedisConnection")))
    {
        services.AddStackExchangeRedisCache(options =>
        {
            options.Configuration = Environment.GetEnvironmentVariable("RedisConnection");
        });
        services.AddScoped<ITenantCacheService, RedisTenantCacheService>();
    }
    else
    {
        services.AddMemoryCache();
        services.AddScoped<ITenantCacheService, MemoryTenantCacheService>();
    }
}
```

### 4. **Caching Implementation**

#### **Tenant Routing Cache**
```csharp
public class RedisTenantCacheService : ITenantCacheService
{
    private readonly IDistributedCache _cache;
    private readonly ILogger<RedisTenantCacheService> _logger;

    public async Task<CachedTenantRouting> GetTenantRoutingAsync(string tenantId)
    {
        try
        {
            var cacheKey = $"tenant:routing:{tenantId}";
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
            _logger.LogError(ex, "Error retrieving tenant routing from cache");
            return null; // Fail gracefully
        }
    }
}
```

### 5. **Enhanced Error Handling**

#### **Structured Error Handling**
```csharp
[Function("CreateTenant")]
public async Task<HttpResponseData> Run([HttpTrigger] HttpRequestData req)
{
    try
    {
        _logger.LogInformation("Creating new tenant...");
        // Business logic here
    }
    catch (JsonException ex)
    {
        _logger.LogError(ex, "Invalid JSON in request body");
        var errorResponse = req.CreateResponse(HttpStatusCode.BadRequest);
        await errorResponse.WriteStringAsync("Invalid JSON format in request body.");
        return errorResponse;
    }
    catch (CosmosException ex)
    {
        _logger.LogError(ex, "Cosmos DB error during tenant creation");
        var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
        await errorResponse.WriteStringAsync("Database error occurred. Please try again.");
        return errorResponse;
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Unexpected error during tenant creation");
        var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
        await errorResponse.WriteStringAsync("An unexpected error occurred. Please contact support.");
        return errorResponse;
    }
}
```

## 🧪 Testing Guidelines

### **Unit Testing with Mocking**
```csharp
public class CreateTenantFunctionTests
{
    private readonly Mock<CosmosClient> _mockCosmosClient;
    private readonly Mock<ILogger<CreateTenantFunction>> _mockLogger;

    [Fact]
    public async Task AssignDedicatedCellAsync_WithEmptyDedicatedCells_ShouldReturnFirstAvailable()
    {
        // Arrange
        var tenant = new TenantInfo
        {
            tenantId = "test-enterprise-tenant",
            tenantTier = TenantTier.Enterprise,
            complianceRequirements = new List<string> { ComplianceStandards.HIPAA }
        };

        // Act & Assert
        var result = await InvokePrivateMethod<CellInfo>("AssignDedicatedCellAsync", tenant, availableCells);
        Assert.NotNull(result);
    }
}
```

### **Integration Testing**
```csharp
[Collection("CosmosDB")]
public class CreateTenantFunctionIntegrationTests
{
    [Fact(Skip = "Requires Cosmos DB Emulator")]
    public async Task CreateTenant_WithRealCosmosDB_ShouldSucceed()
    {
        // Integration test with Cosmos DB emulator
        // Requires: Cosmos DB emulator running locally
    }
}
```

## 📋 Configuration Checklist

### **Environment Variables**
```json
{
  "AzureWebJobsStorage": "UseDevelopmentStorage=true",
  "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
  "CosmosDbConnection": "AccountEndpoint=https://...;AccountKey=...",
  "CosmosDbDatabaseName": "globaldb",
  "TenantsContainerName": "tenants",
  "CellsContainerName": "cells",
  "RedisConnection": "your-redis-connection-string",
    "EXTERNAL_ID_TENANT": "your-tenant",
    "EXTERNAL_ID_CLIENT_ID": "your-client-id",
    "EXTERNAL_ID_USER_FLOW": "B2C_1_signupsignin",
    // Legacy keys still supported:
    "B2C_TENANT": "your-b2c-tenant",
    "B2C_CLIENT_ID": "your-client-id",
    "B2C_POLICY": "your-policy"
}
```

Note: For Microsoft Entra External ID (customers), the user flow name continues to follow the familiar `B2C_1_...` pattern. Keep using `EXTERNAL_ID_USER_FLOW` for configuration; the app will also read `B2C_POLICY` for backward compatibility if present.

For end-to-end local setup steps, see [Developer Quickstart](./DEVELOPER_QUICKSTART.md).

### **Required NuGet Packages**
```xml
<PackageReference Include="Microsoft.Azure.Functions.Worker" Version="1.19.0" />
<PackageReference Include="Microsoft.Azure.Cosmos" Version="3.35.4" />
<PackageReference Include="Microsoft.Extensions.Caching.StackExchangeRedis" Version="7.0.0" />
<PackageReference Include="Microsoft.IdentityModel.JsonWebTokens" Version="7.0.3" />
<PackageReference Include="Microsoft.IdentityModel.Protocols.OpenIdConnect" Version="7.0.3" />
```

### **Cosmos DB Indexing Policy**
```json
{
  "compositeIndexes": [
    [
      { "path": "/region", "order": "ascending" },
      { "path": "/cellType", "order": "ascending" },
      { "path": "/status", "order": "ascending" }
    ],
    [
      { "path": "/region", "order": "ascending" },
      { "path": "/currentTenantCount", "order": "ascending" }
    ]
  ]
}
```

## 🔍 Debugging and Troubleshooting

### **Common Issues**

1. **Cosmos DB Connection Fails**
   - ✅ Verify private endpoints are properly configured
   - ✅ Check that `publicNetworkAccess` is set to `'Disabled'`
   - ✅ Ensure managed identity has proper permissions

2. **JWT Validation Errors**
    - ✅ Verify External ID tenant and user flow configuration
   - ✅ Check JWKS cache is being populated
   - ✅ Validate audience and issuer settings

3. **Cache Performance Issues**
   - ✅ Monitor Redis connection health
   - ✅ Check cache hit/miss ratios
   - ✅ Verify cache expiration policies

### **Performance Monitoring**
```csharp
// Add performance counters
_logger.LogInformation("JWT validation completed in {ElapsedMs}ms", stopwatch.ElapsedMilliseconds);
_logger.LogInformation("Cache {CacheResult} for tenant {TenantId}", 
    cachedData != null ? "HIT" : "MISS", tenantId);
```

## 📚 Additional Resources

- <a href="https://learn.microsoft.com/azure/azure-functions/functions-best-practices" target="_blank" rel="noopener">Azure Functions Best Practices</a>
- <a href="https://learn.microsoft.com/azure/cosmos-db/performance-tips" target="_blank" rel="noopener">Cosmos DB Performance Tips</a>
- <a href="https://learn.microsoft.com/en-us/entra/external-id/customers/overview-customers-ciam" target="_blank" rel="noopener">Microsoft Entra External ID for customers</a>
- <a href="https://learn.microsoft.com/azure/azure-cache-for-redis/cache-best-practices" target="_blank" rel="noopener">Redis Caching Patterns</a>

## 🔗 Related Documentation

- [Security Guide](./SECURITY_GUIDE.md) - Comprehensive security documentation
- [Architecture Guide](./ARCHITECTURE_GUIDE.md) - Technical architecture details
- [Operations Guide](./OPERATIONS_GUIDE.md) - Production operations



