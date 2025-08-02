using System;
using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Cosmos;
using System.Text.Json;
using System.Threading.Tasks;

public class CreateTenantFunction
{
    private readonly CosmosClient _cosmosClient;
    private readonly Container _container;

    public CreateTenantFunction()
    {
        string cosmosDbConnectionString = Environment.GetEnvironmentVariable("CosmosDbConnection");
        string databaseName = Environment.GetEnvironmentVariable("CosmosDbDatabaseName") ?? "globaldb";
        string containerName = Environment.GetEnvironmentVariable("CosmosDbContainerName") ?? "tenants";
        _cosmosClient = new CosmosClient(cosmosDbConnectionString);
        _container = _cosmosClient.GetContainer(databaseName, containerName);
    }

    [Function("CreateTenant")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "tenant")] HttpRequestData req)
    {
        var tenant = await req.ReadFromJsonAsync<TenantInfo>();

        // Assign CELL logic here (e.g., round-robin, least-loaded, etc.)
        tenant.cellBackendPool = AssignCellForTenant(tenant);

        await _container.CreateItemAsync(tenant, new PartitionKey(tenant.tenantId));

        var response = req.CreateResponse(HttpStatusCode.Created);
        await response.WriteAsJsonAsync(tenant);
        return response;
    }

    private string AssignCellForTenant(TenantInfo tenant)
    {
        // TODO: Implement your CELL assignment logic here
        // For demo, return a static value
        return "cell2-eastus-backend";
    }
}

public class TenantInfo
{
    public string tenantId { get; set; }
    public string subdomain { get; set; }
    public string cellBackendPool { get; set; }
}