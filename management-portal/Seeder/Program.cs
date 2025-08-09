using Azure.Cosmos;
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
var tenants = (await db.CreateContainerIfNotExistsAsync(new CosmosContainerProperties("tenants", "/tenantId"))).Container;
var cells = (await db.CreateContainerIfNotExistsAsync(new CosmosContainerProperties("cells", "/cellId"))).Container;
var ops = (await db.CreateContainerIfNotExistsAsync(new CosmosContainerProperties("operations", "/tenantId"))).Container;
var catalogs = (await db.CreateContainerIfNotExistsAsync(new CosmosContainerProperties("catalogs", "/type"))).Container;

await Upsert(tenants, new { id = "contoso", tenantId = "contoso", displayName = "Contoso", domain = "contoso.com", tier = "enterprise", status = "active", cellId = "cell-eastus-1" });
await Upsert(tenants, new { id = "fabrikam", tenantId = "fabrikam", displayName = "Fabrikam", domain = "fabrikam.io", tier = "smb", status = "active", cellId = "cell-westus-1" });

await Upsert(cells, new { id = "cell-eastus-1", cellId = "cell-eastus-1", region = "eastus", availabilityZone = "1", status = "healthy", capacityUsed = 60, capacityTotal = 100 });
await Upsert(cells, new { id = "cell-westus-1", cellId = "cell-westus-1", region = "westus", availabilityZone = "2", status = "healthy", capacityUsed = 40, capacityTotal = 100 });

await Upsert(ops, new { id = "op-001", tenantId = "contoso", type = "migrate", status = "running", createdAt = DateTime.UtcNow });
await Upsert(ops, new { id = "op-002", tenantId = "fabrikam", type = "suspend", status = "completed", createdAt = DateTime.UtcNow.AddDays(-1) });

// Seed catalogs
await Upsert(catalogs, new { id = "tiers-v1", type = "tiers", values = new[] { "startup", "smb", "enterprise" } });

Console.WriteLine("Seed complete.");
return 0;

static async Task Upsert(CosmosContainer container, dynamic item)
{
    // Determine PK based on known containers
    string pk = item?.tenantId ?? item?.cellId ?? item?.type ?? item?.id;
    await container.UpsertItemAsync(item, partitionKey: new PartitionKey(pk));
}
