using Microsoft.Azure.Cosmos;
using Azure.Identity;
using System.Net;

// Prefer AAD auth: provide COSMOS_ACCOUNT_ENDPOINT (https://<account>.documents.azure.com/) and use DefaultAzureCredential.
// Fallback to COSMOS_CONNECTION_STRING for local emulator/dev scenarios.
var endpoint = Environment.GetEnvironmentVariable("COSMOS_ACCOUNT_ENDPOINT");
var connectionString = Environment.GetEnvironmentVariable("COSMOS_CONNECTION_STRING");

CosmosClient client;
try
{
    if (!string.IsNullOrWhiteSpace(endpoint))
    {
        var tenantId = Environment.GetEnvironmentVariable("AZURE_TENANT_ID");
        Console.WriteLine($"Using AAD auth for Cosmos account: {endpoint}");
        if (!string.IsNullOrWhiteSpace(tenantId))
        {
            Console.WriteLine($"Requested tenant: {tenantId}");
        }
        // Use Azure CLI credential (tenant-scoped) first; fallback to DefaultAzureCredential without interactive
        var credChain = new Azure.Core.TokenCredential[]
        {
            new Azure.Identity.AzureCliCredential(new Azure.Identity.AzureCliCredentialOptions { TenantId = tenantId }),
            new DefaultAzureCredential(new DefaultAzureCredentialOptions{ TenantId = tenantId, ExcludeInteractiveBrowserCredential = true })
        };
        var credential = new Azure.Identity.ChainedTokenCredential(credChain);
        client = new CosmosClient(endpoint, credential, new CosmosClientOptions
        {
            ConnectionMode = ConnectionMode.Direct
        });
    }
    else if (!string.IsNullOrWhiteSpace(connectionString))
    {
        Console.WriteLine("Using connection string auth for Cosmos (dev/emulator)");
        // Accept Cosmos Emulator self-signed cert in local dev.
        ServicePointManager.ServerCertificateValidationCallback += (_, _, _, _) => true;
        client = new CosmosClient(connectionString);
    }
    else
    {
        Console.Error.WriteLine("Neither COSMOS_ACCOUNT_ENDPOINT nor COSMOS_CONNECTION_STRING is set. Set COSMOS_ACCOUNT_ENDPOINT for AAD auth.");
        return 1;
    }
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Failed to create CosmosClient: {ex.Message}");
    return 1;
}
var db = (await client.CreateDatabaseIfNotExistsAsync("stamps-control-plane")).Database;
var tenants = (await db.CreateContainerIfNotExistsAsync(new ContainerProperties("tenants", "/tenantId"))).Container;
var cells = (await db.CreateContainerIfNotExistsAsync(new ContainerProperties("cells", "/cellId"))).Container;
var ops = (await db.CreateContainerIfNotExistsAsync(new ContainerProperties("operations", "/tenantId"))).Container;
var catalogs = (await db.CreateContainerIfNotExistsAsync(new ContainerProperties("catalogs", "/type"))).Container;

// Regions and 6 cells (3 per region)
var regions = new[] { "eastus", "westus" };
foreach (var region in regions)
{
    for (var i = 1; i <= 3; i++)
    {
        var cellId = $"cell-{region}-{i}";
        await Upsert(cells, new
        {
            id = cellId,
            cellId,
            region,
            availabilityZone = i.ToString(),
            status = "healthy",
            capacityUsed = 20 * i,
            capacityTotal = 100
        });
    }
}

// Tenants mapped to the cells
var seedTenants = new[]
{
    new { id = "contoso", displayName = "Contoso", domain = "contoso.com", tier = "enterprise", status = "active", cellId = "cell-eastus-1" },
    new { id = "fabrikam", displayName = "Fabrikam", domain = "fabrikam.io", tier = "smb", status = "active", cellId = "cell-westus-1" },
    new { id = "adatum", displayName = "Adatum", domain = "adatum.com", tier = "startup", status = "active", cellId = "cell-eastus-2" },
    new { id = "northwind", displayName = "Northwind", domain = "northwind.com", tier = "smb", status = "active", cellId = "cell-westus-2" },
    new { id = "tailspin", displayName = "Tailspin", domain = "tailspin.io", tier = "enterprise", status = "active", cellId = "cell-eastus-3" },
    new { id = "wingtip", displayName = "Wingtip", domain = "wingtip.com", tier = "startup", status = "active", cellId = "cell-westus-3" }
};

foreach (var t in seedTenants)
{
    await Upsert(tenants, new
    {
        id = t.id,
        tenantId = t.id,
        t.displayName,
        t.domain,
        t.tier,
        t.status,
        t.cellId
    });
}

// Recent operations for a few tenants
var now = DateTime.UtcNow;
var seedOps = new[]
{
    new { id = "op-001", tenantId = "contoso", type = "migrate", status = "running", createdAt = now.AddMinutes(-30) },
    new { id = "op-002", tenantId = "fabrikam", type = "suspend", status = "completed", createdAt = now.AddDays(-1) },
    new { id = "op-003", tenantId = "adatum", type = "scaleout", status = "completed", createdAt = now.AddHours(-2) },
    new { id = "op-004", tenantId = "northwind", type = "rebalance", status = "queued", createdAt = now }
};
foreach (var o in seedOps)
{
    await Upsert(ops, o);
}

// Catalogs
await Upsert(catalogs, new { id = "tiers-v1", type = "tiers", values = new[] { "startup", "smb", "enterprise" } });

Console.WriteLine("Seed complete.");
return 0;

static async Task Upsert(Container container, dynamic item)
{
    // Determine PK based on container name to avoid dynamic binder errors
    string pk;
    switch (container.Id)
    {
        case "tenants":
            pk = (string)item.tenantId;
            break;
        case "cells":
            pk = (string)item.cellId;
            break;
        case "operations":
            pk = (string)item.tenantId;
            break;
        case "catalogs":
            pk = (string)item.type;
            break;
        default:
            pk = (string)item.id;
            break;
    }
    await container.UpsertItemAsync(item, new PartitionKey(pk));
}
