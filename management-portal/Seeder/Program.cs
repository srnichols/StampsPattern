using Microsoft.Azure.Cosmos;
using System.Net;

var conn = Environment.GetEnvironmentVariable("COSMOS_CONNECTION_STRING");
if (string.IsNullOrWhiteSpace(conn))
{
    Console.Error.WriteLine("COSMOS_CONNECTION_STRING not set");
    return 1;
}

// Accept Cosmos Emulator self-signed cert in local dev.
ServicePointManager.ServerCertificateValidationCallback += (_, _, _, _) => true;
var client = new CosmosClient(conn);
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
    // Determine PK based on known containers
    string pk = item?.tenantId ?? item?.cellId ?? item?.type ?? item?.id;
    await container.UpsertItemAsync(item, partitionKey: new PartitionKey(pk));
}
