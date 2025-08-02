using System;
using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Cosmos;
using System.Threading.Tasks;
using System.Security.Claims;
using Microsoft.IdentityModel.Tokens;
using Microsoft.IdentityModel.JsonWebTokens;

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

// Helper class for JWT validation (simplified, production code should cache keys and handle exceptions)
public static class JwtValidator
{
    public static async Task<ClaimsPrincipal?> ValidateTokenAsync(HttpRequestData req)
    {
        var authHeader = req.Headers.GetValues("Authorization").FirstOrDefault();
        if (string.IsNullOrEmpty(authHeader) || !authHeader.StartsWith("Bearer "))
            return null;

        var token = authHeader.Substring("Bearer ".Length);

        // These values should be set in your configuration/environment
        var tenant = Environment.GetEnvironmentVariable("B2C_TENANT") ?? "<your-b2c-tenant-name>";
        var clientId = Environment.GetEnvironmentVariable("B2C_CLIENT_ID") ?? "<your-b2c-client-id>";
        var policy = Environment.GetEnvironmentVariable("B2C_POLICY") ?? "<your-b2c-policy>";

        var authority = $"https://{tenant}.b2clogin.com/{tenant}.onmicrosoft.com/{policy}/v2.0/";
        var validIssuer = authority;
        var validAudience = clientId;

        var tokenHandler = new JsonWebTokenHandler();
        var configManager = new Microsoft.IdentityModel.Protocols.ConfigurationManager<Microsoft.IdentityModel.Protocols.OpenIdConnect.OpenIdConnectConfiguration>(
            $"{authority}.well-known/openid-configuration",
            new Microsoft.IdentityModel.Protocols.OpenIdConnect.OpenIdConnectConfigurationRetriever()
        );
        var config = await configManager.GetConfigurationAsync(CancellationToken.None);

        var validationParameters = new TokenValidationParameters
        {
            ValidIssuer = validIssuer,
            ValidAudiences = new[] { validAudience },
            IssuerSigningKeys = config.SigningKeys
        };

        var result = tokenHandler.ValidateToken(token, validationParameters);
        return result.IsValid ? result.ClaimsIdentity != null ? new ClaimsPrincipal(result.ClaimsIdentity) : null : null;
    }
}

public class TenantInfo
{
    public string tenantId { get; set; }
    public string subdomain { get; set; }
    public string cellBackendPool { get; set; }
}