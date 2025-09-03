using System;
using System.Threading;
using System.Threading.Tasks;
using Azure;
using Azure.Storage.Blobs;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace TaskTracker.Blazor.Services.Health;

public sealed class BlobStorageHealthCheck : IHealthCheck
{
    private readonly BlobServiceClient _blobServiceClient;

    public BlobStorageHealthCheck(BlobServiceClient blobServiceClient)
    {
        _blobServiceClient = blobServiceClient;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            // List one container lazily to validate connectivity and auth
            await foreach (var _ in _blobServiceClient.GetBlobContainersAsync(cancellationToken: cancellationToken))
            {
                break;
            }
            return HealthCheckResult.Healthy("Blob storage reachable.");
        }
        catch (RequestFailedException rex)
        {
            return HealthCheckResult.Unhealthy($"Blob storage error: {rex.Status}", rex);
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Blob storage unreachable.", ex);
        }
    }
}
