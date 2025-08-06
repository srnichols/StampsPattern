using System;
using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Cosmos;
using System.Threading.Tasks;
using System.Security.Claims;
using Microsoft.IdentityModel.Tokens;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using System.Linq;

public class GetTenantInfoFunction
{
    private readonly CosmosClient _cosmosClient;
    private readonly Container _container;

    public GetTenantInfoFunction()
    {
        string cosmosDbConnectionString = Environment.GetEnvironmentVariable("CosmosDbConnection");
        string databaseName = Environment.GetEnvironmentVariable("CosmosDbDatabaseName") ?? "globaldb";
        string containerName = Environment.GetEnvironmentVariable("CosmosDbContainerName") ?? "tenants";
        _cosmosClient = new CosmosClient(cosmosDbConnectionString);
        _container = _cosmosClient.GetContainer(databaseName, containerName);
    }

    [Function("GetTenantInfo")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "tenant/{tenantId}")] HttpRequestData req,
        string tenantId)
    {
        // Validate Azure AD B2C JWT token
        var principal = await JwtValidator.ValidateTokenAsync(req);
        if (principal == null)
        {
            var unauthorized = req.CreateResponse(HttpStatusCode.Unauthorized);
            await unauthorized.WriteStringAsync("Invalid or missing token.");
            return unauthorized;
        }

        try
        {
            ItemResponse<TenantInfo> responseItem = await _container.ReadItemAsync<TenantInfo>(tenantId, new PartitionKey(tenantId));
            var response = req.CreateResponse(HttpStatusCode.OK);
            await response.WriteAsJsonAsync(responseItem.Resource);
            return response;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            var response = req.CreateResponse(HttpStatusCode.NotFound);
            await response.WriteStringAsync("Tenant not found.");
            return response;
        }
    }
}

// Helper class for JWT validation with enhanced security and caching
public static class JwtValidator
{
    private static readonly MemoryCache _jwksCache = new MemoryCache(new MemoryCacheOptions
    {
        SizeLimit = 100
    });
    
    private static readonly ILogger _logger = LoggerFactory.Create(builder => builder.AddConsole()).CreateLogger("JwtValidator");

    public static async Task<ClaimsPrincipal?> ValidateTokenAsync(HttpRequestData req)
    {
        var authHeader = req.Headers.GetValues("Authorization").FirstOrDefault();
        if (string.IsNullOrEmpty(authHeader) || !authHeader.StartsWith("Bearer "))
        {
            _logger.LogWarning("Missing or invalid authorization header");
            return null;
        }

        var token = authHeader.Substring("Bearer ".Length);

        try
        {
            // These values should be set in your configuration/environment
            var tenant = Environment.GetEnvironmentVariable("B2C_TENANT") ?? throw new InvalidOperationException("B2C_TENANT not configured");
            var clientId = Environment.GetEnvironmentVariable("B2C_CLIENT_ID") ?? throw new InvalidOperationException("B2C_CLIENT_ID not configured");
            var policy = Environment.GetEnvironmentVariable("B2C_POLICY") ?? throw new InvalidOperationException("B2C_POLICY not configured");

            var authority = $"https://{tenant}.b2clogin.com/{tenant}.onmicrosoft.com/{policy}/v2.0/";
            var metadataAddress = $"{authority}.well-known/openid-configuration";
            
            // Cache JWKS configuration for performance
            var cacheKey = $"jwks_{tenant}_{policy}";
            if (!_jwksCache.TryGetValue(cacheKey, out Microsoft.IdentityModel.Protocols.OpenIdConnect.OpenIdConnectConfiguration? config))
            {
                var configManager = new Microsoft.IdentityModel.Protocols.ConfigurationManager<Microsoft.IdentityModel.Protocols.OpenIdConnect.OpenIdConnectConfiguration>(
                    metadataAddress,
                    new Microsoft.IdentityModel.Protocols.OpenIdConnect.OpenIdConnectConfigurationRetriever()
                );
                
                config = await configManager.GetConfigurationAsync(CancellationToken.None);
                _jwksCache.Set(cacheKey, config, TimeSpan.FromHours(24)); // Cache for 24 hours
            }

            var tokenHandler = new JsonWebTokenHandler();
            var validationParameters = new TokenValidationParameters
            {
                ValidIssuer = authority, // Validate issuer
                ValidAudiences = new[] { clientId }, // Validate audience  
                IssuerSigningKeys = config.SigningKeys,
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                ClockSkew = TimeSpan.FromMinutes(5) // Allow 5 minute clock skew
            };

            var result = await tokenHandler.ValidateTokenAsync(token, validationParameters);
            
            if (!result.IsValid)
            {
                _logger.LogWarning("Token validation failed: {Exception}", result.Exception?.Message);
                return null;
            }

            return result.ClaimsIdentity != null ? new ClaimsPrincipal(result.ClaimsIdentity) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error validating JWT token");
            return null;
        }
    }
}

public class TenantInfo
{
    public string tenantId { get; set; }
    public string subdomain { get; set; }
    public string cellBackendPool { get; set; }
}