using Azure.Storage.Blobs;
using Azure.Storage.Sas;
using Azure.Storage.Blobs.Models;
using Microsoft.Extensions.Options;
using TaskTracker.Blazor.Services.Options;

namespace TaskTracker.Blazor.Services;

public interface IBlobStorageService
{
    Task<string> GenerateUploadSasAsync(string tenantId, Guid taskId, string fileName);
    Task<bool> DeleteBlobAsync(string blobUri);
    Task<string> GenerateDownloadSasAsync(string blobUri, TimeSpan expiration);
    Task<string> UploadAsync(string tenantId, Guid taskId, string fileName, string contentType, Stream content, CancellationToken ct = default);
}

public class BlobStorageService : IBlobStorageService
{
    private readonly BlobServiceClient _blobServiceClient;
    private readonly string _containerName;
    private readonly string _blobConnectionString;

    public BlobStorageService(BlobServiceClient blobServiceClient, IOptions<BlobOptions> options, IConfiguration configuration)
    {
        _blobServiceClient = blobServiceClient;
        var opts = options.Value;
        _containerName = opts.ContainerName ?? configuration["BlobStorage:ContainerName"] ?? "task-attachments";
        _blobConnectionString = opts.ConnectionString ?? configuration.GetConnectionString("BlobStorage") ?? "UseDevelopmentStorage=true";
    }

    public async Task<string> GenerateUploadSasAsync(string tenantId, Guid taskId, string fileName)
    {
        var containerClient = _blobServiceClient.GetBlobContainerClient(_containerName);
        await containerClient.CreateIfNotExistsAsync(PublicAccessType.None);

        // Create tenant-scoped blob path
        var blobPath = $"tenants/{tenantId}/tasks/{taskId}/{Guid.NewGuid()}_{fileName}";
        var blobClient = containerClient.GetBlobClient(blobPath);

        // Generate SAS token with write permissions
        if (blobClient.CanGenerateSasUri)
        {
            var sasBuilder = new BlobSasBuilder
            {
                BlobContainerName = _containerName,
                BlobName = blobPath,
                Resource = "b", // blob
                ExpiresOn = DateTimeOffset.UtcNow.AddMinutes(10)
            };

            sasBuilder.SetPermissions(BlobSasPermissions.Create | BlobSasPermissions.Write);

            return blobClient.GenerateSasUri(sasBuilder).ToString();
        }

        throw new InvalidOperationException("Unable to generate SAS token for blob upload");
    }

    public async Task<bool> DeleteBlobAsync(string blobUri)
    {
        try
        {
            var uri = new Uri(blobUri);
            // Use the authenticated service client to resolve the blob (works with Azurite/dev connections)
            if (!TryParseContainerAndBlob(uri, out var container, out var blobName))
            {
                return false;
            }
            var containerClient = _blobServiceClient.GetBlobContainerClient(container);
            var blobClient = containerClient.GetBlobClient(blobName);
            var response = await blobClient.DeleteIfExistsAsync();
            return response.Value;
        }
        catch
        {
            return false;
        }
    }

    public Task<string> GenerateDownloadSasAsync(string blobUri, TimeSpan expiration)
    {
        var uri = new Uri(blobUri);
        // Resolve the blob using the authenticated service client to enable SAS generation
        if (TryParseContainerAndBlob(uri, out var container, out var blobName))
        {
            var blobClient = _blobServiceClient.GetBlobContainerClient(container).GetBlobClient(blobName);
            if (blobClient.CanGenerateSasUri)
            {
                var sasBuilder = new BlobSasBuilder
                {
                    BlobContainerName = container,
                    BlobName = blobName,
                    Resource = "b",
                    ExpiresOn = DateTimeOffset.UtcNow.Add(expiration)
                };
                sasBuilder.SetPermissions(BlobSasPermissions.Read);
                var sas = blobClient.GenerateSasUri(sasBuilder).ToString();
                if (uri.Host.Equals("azurite", StringComparison.OrdinalIgnoreCase))
                {
                    sas = sas.Replace("http://azurite:10000", "http://localhost:10000", StringComparison.OrdinalIgnoreCase);
                }
                return Task.FromResult(sas);
            }

            // Fallback: construct a credentialed BlobClient from the connection string
            var credBlobClient = new BlobClient(_blobConnectionString, container, blobName);
            if (credBlobClient.CanGenerateSasUri)
            {
                var sasBuilder = new BlobSasBuilder
                {
                    BlobContainerName = container,
                    BlobName = blobName,
                    Resource = "b",
                    ExpiresOn = DateTimeOffset.UtcNow.Add(expiration)
                };
                sasBuilder.SetPermissions(BlobSasPermissions.Read);
                var sas = credBlobClient.GenerateSasUri(sasBuilder).ToString();
                if (uri.Host.Equals("azurite", StringComparison.OrdinalIgnoreCase))
                {
                    sas = sas.Replace("http://azurite:10000", "http://localhost:10000", StringComparison.OrdinalIgnoreCase);
                }
                return Task.FromResult(sas);
            }
        }

        // Fallback: return original (rewritten for localhost) if SAS cannot be generated
        var original = blobUri;
        if (uri.Host.Equals("azurite", StringComparison.OrdinalIgnoreCase))
        {
            original = original.Replace("http://azurite:10000", "http://localhost:10000", StringComparison.OrdinalIgnoreCase);
        }
        return Task.FromResult(original);
    }

    public async Task<string> UploadAsync(string tenantId, Guid taskId, string fileName, string contentType, Stream content, CancellationToken ct = default)
    {
        var containerClient = _blobServiceClient.GetBlobContainerClient(_containerName);
        await containerClient.CreateIfNotExistsAsync(PublicAccessType.None, cancellationToken: ct);

        var safeName = fileName.Replace("..", string.Empty).Replace("/", "_").Replace("\\", "_");
        var blobPath = $"tenants/{tenantId}/tasks/{taskId}/{Guid.NewGuid()}_{safeName}";
        var blobClient = containerClient.GetBlobClient(blobPath);
        await blobClient.UploadAsync(content, new BlobUploadOptions { HttpHeaders = new BlobHttpHeaders { ContentType = contentType } }, ct);
        return blobClient.Uri.ToString();
    }

    private static bool TryParseContainerAndBlob(Uri blobUri, out string container, out string blobName)
    {
        // Supports both Azurite and Azure URIs and correctly decodes URL-encoded names.
        // Azurite path: /devstoreaccount1/{container}/{blob...}
        // Azure path:   /{container}/{blob...}
        container = string.Empty;
        blobName = string.Empty;

        var segments = blobUri.AbsolutePath.Split('/', StringSplitOptions.RemoveEmptyEntries);
        if (segments.Length == 0)
        {
            return false;
        }

        // Determine container segment index
        var host = blobUri.Host;
        var containerIndex = 0;
        if ((host.Equals("azurite", StringComparison.OrdinalIgnoreCase) && segments.Length >= 2)
            || (segments.Length >= 2 && segments[0].Equals("devstoreaccount1", StringComparison.OrdinalIgnoreCase)))
        {
            // Azurite includes the account name as the first path segment
            containerIndex = 1;
        }

        if (segments.Length <= containerIndex)
        {
            return false;
        }

        container = Uri.UnescapeDataString(segments[containerIndex]);

        if (segments.Length <= containerIndex + 1)
        {
            return false; // no blob path
        }

        var blobPathEncoded = string.Join('/', segments.Skip(containerIndex + 1));
        blobName = Uri.UnescapeDataString(blobPathEncoded);
        return true;
    }
}