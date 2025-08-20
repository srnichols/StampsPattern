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
        string? cosmosDbConnectionString = Environment.GetEnvironmentVariable("CosmosDbConnection");
        if (string.IsNullOrEmpty(cosmosDbConnectionString))
            throw new InvalidOperationException("CosmosDbConnection environment variable is not set.");
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
        if (user == null)
        {
            var badResponse = req.CreateResponse(HttpStatusCode.BadRequest);
            await badResponse.WriteStringAsync("Invalid user payload.");
            return badResponse;
        }
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
    public string tenantId { get; set; } = string.Empty;
    public string userId { get; set; } = string.Empty;
    public string email { get; set; } = string.Empty;
    public string role { get; set; } = string.Empty;
}