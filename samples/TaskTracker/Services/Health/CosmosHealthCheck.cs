using System.Threading;
using System.Threading.Tasks;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace TaskTracker.Blazor.Services.Health;

public sealed class CosmosHealthCheck : IHealthCheck
{
    private readonly CosmosClient _cosmosClient;
    private readonly IConfiguration _configuration;

    public CosmosHealthCheck(CosmosClient cosmosClient, IConfiguration configuration)
    {
        _cosmosClient = cosmosClient;
        _configuration = configuration;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            // Basic account check (doesn't require specific database existence)
            await _cosmosClient.ReadAccountAsync();

            // Optionally verify our database exists/accessible
            var dbName = _configuration["CosmosDb:DatabaseName"] ?? "TaskTrackerDb";
            var db = _cosmosClient.GetDatabase(dbName);
            var resp = await db.ReadAsync(cancellationToken: cancellationToken);
            return resp.StatusCode == System.Net.HttpStatusCode.OK
                ? HealthCheckResult.Healthy("Cosmos reachable and database present.")
                : HealthCheckResult.Degraded($"Cosmos reachable but database '{dbName}' had status {resp.StatusCode}.");
        }
        catch (CosmosException cex)
        {
            return HealthCheckResult.Unhealthy($"Cosmos error: {cex.StatusCode}", cex);
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Cosmos unreachable.", ex);
        }
    }
}
