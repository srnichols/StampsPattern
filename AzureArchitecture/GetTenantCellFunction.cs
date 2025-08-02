using System;
using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Cosmos;
using System.Text.Json;
using System.Threading.Tasks;
using System.Collections.Generic;

public class GetTenantCellFunction
{
    private readonly CosmosClient _cosmosClient;
    private readonly Container _container;

    public GetTenantCellFunction()
    {
        // Use environment variables or configuration for these values
        string cosmosDbConnectionString = Environment.GetEnvironmentVariable("CosmosDbConnection");
        string databaseName = Environment.GetEnvironmentVariable("CosmosDbDatabaseName") ?? "globaldb";
        string containerName = Environment.GetEnvironmentVariable("CosmosDbContainerName") ?? "tenants";
        _cosmosClient = new CosmosClient(cosmosDbConnectionString);
        _container = _cosmosClient.GetContainer(databaseName, containerName);
    }

    [Function("GetTenantCell")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "tenant/{subdomain}")] HttpRequestData req,
        string subdomain)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.subdomain = @subdomain")
            .WithParameter("@subdomain", subdomain);

        var iterator = _container.GetItemQueryIterator<TenantInfo>(query);
        TenantInfo tenant = null;
        while (iterator.HasMoreResults)
        {
            foreach (var item in await iterator.ReadNextAsync())
            {
                tenant = item;
                break;
            }
        }

        var response = req.CreateResponse();
        if (tenant == null)
        {
            response.StatusCode = HttpStatusCode.NotFound;
            await response.WriteStringAsync("Tenant not found.");
            return response;
        }

        response.StatusCode = HttpStatusCode.OK;
        await response.WriteAsJsonAsync(new 
        { 
            tenant.cellBackendPool,
            tenant.cellName,
            tenant.tenantTier,
            tenant.region,
            tenant.status
        });
        return response;
    }
}

/// <summary>
/// Enhanced tenant information supporting flexible tenancy models
/// </summary>
public class TenantInfo
{
    public string tenantId { get; set; }
    public string subdomain { get; set; }
    public string cellBackendPool { get; set; }
    public string cellName { get; set; }
    public TenantTier? tenantTier { get; set; } = TenantTier.Shared;
    public string region { get; set; } = "eastus";
    public List<string> complianceRequirements { get; set; } = new List<string>();
    public TenantStatus status { get; set; } = TenantStatus.Active;
    public DateTime createdDate { get; set; }
    public DateTime? lastModifiedDate { get; set; }
    public int estimatedMonthlyApiCalls { get; set; } = 10000;
    public string contactEmail { get; set; }
    public string organizationName { get; set; }
}

/// <summary>
/// Tenant tier enumeration for flexible tenancy models
/// </summary>
public enum TenantTier
{
    Startup,     // Small tenants, shared CELLs, cost-optimized
    SMB,         // Small-medium business, shared CELLs, standard features
    Shared,      // General shared tenancy model
    Enterprise,  // Large enterprise, dedicated CELLs, premium features
    Dedicated    // Dedicated infrastructure, full isolation
}

/// <summary>
/// Tenant status enumeration
/// </summary>
public enum TenantStatus
{
    Active,
    Inactive,
    Suspended,
    Migrating
}