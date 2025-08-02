using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Cosmos;
using System.Threading.Tasks;

public class AddUserToTenantFunction
{
    private readonly CosmosClient _cosmosClient;
    private readonly Container _container;

    public AddUserToTenantFunction()
    {
        string cosmosDbConnectionString = Environment.GetEnvironmentVariable("CosmosDbConnection");
        string databaseName = Environment.GetEnvironmentVariable("CosmosDbDatabaseName") ?? "globaldb";
        string containerName = Environment.GetEnvironmentVariable("CosmosDbUserContainerName") ?? "tenantUsers";
        _cosmosClient = new CosmosClient(cosmosDbConnectionString);
        _container = _cosmosClient.GetContainer(databaseName, containerName);
    }

    [Function("AddUserToTenant")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "tenant/{tenantId}/user")] HttpRequestData req,
        string tenantId)
    {
        var user = await req.ReadFromJsonAsync<TenantUserInfo>();
        user.tenantId = tenantId;
        user.userId = Guid.NewGuid().ToString();
        await _container.CreateItemAsync(user, new PartitionKey(tenantId));

        var response = req.CreateResponse(HttpStatusCode.Created);
        await response.WriteAsJsonAsync(user);
        return response;
    }
}

public class TenantUserInfo
{
    public string tenantId { get; set; }
    public string userId { get; set; }
    public string email { get; set; }
    public string role { get; set; }
}