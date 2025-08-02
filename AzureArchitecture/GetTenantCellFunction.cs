using System;
using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Cosmos;
using System.Text.Json;
using System.Threading.Tasks;

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
        await response.WriteAsJsonAsync(new { tenant.cellBackendPool });
        return response;
    }
}

public class TenantInfo
{
    public string tenantId { get; set; }
    public string subdomain { get; set; }
    public string cellBackendPool { get; set; }
}