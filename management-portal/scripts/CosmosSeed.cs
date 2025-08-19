using System;
using System.Threading.Tasks;
using Microsoft.Azure.Cosmos;
using Newtonsoft.Json;

public class Program
{
    private static readonly string EndpointUri = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT");
    private static readonly string PrimaryKey = Environment.GetEnvironmentVariable("COSMOS_KEY");
    private static readonly string DatabaseId = "stamps-control-plane";
    
    private static CosmosClient cosmosClient;

    public static async Task Main(string[] args)
    {
        try
        {
            Console.WriteLine("Starting Cosmos DB data seeding...");
            
            cosmosClient = new CosmosClient(EndpointUri, PrimaryKey);
            
            await SeedData();
            
            Console.WriteLine("Data seeding completed successfully!");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
        }
        finally
        {
            cosmosClient?.Dispose();
        }
    }

    private static async Task SeedData()
    {
        var database = cosmosClient.GetDatabase(DatabaseId);
        
        // Seed Cells
        var cellsContainer = database.GetContainer("cells");
        
        var cell1 = new
        {
            id = "cell-eastus-01",
            cellId = "cell-eastus-01",
            cellName = "East US Cell 01",
            region = "eastus",
            backendPool = "eastus-pool-01.stamps.com",
            maxCapacity = 1000,
            currentTenants = 2,
            isActive = true,
            cellType = "Standard",
            complianceFeatures = new[] { "SOC2", "GDPR" },
            healthStatus = "Healthy",
            lastHealthCheck = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"),
            deploymentDate = DateTime.UtcNow.AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ssZ"),
            maintenanceWindow = "02:00-04:00 UTC"
        };
        
        var cell2 = new
        {
            id = "cell-westus-01",
            cellId = "cell-westus-01",
            cellName = "West US Cell 01",
            region = "westus",
            backendPool = "westus-pool-01.stamps.com",
            maxCapacity = 2000,
            currentTenants = 1,
            isActive = true,
            cellType = "High Performance",
            complianceFeatures = new[] { "SOC2", "HIPAA", "FedRAMP" },
            healthStatus = "Healthy",
            lastHealthCheck = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"),
            deploymentDate = DateTime.UtcNow.AddDays(-45).ToString("yyyy-MM-ddTHH:mm:ssZ"),
            maintenanceWindow = "03:00-05:00 UTC"
        };
        
        await cellsContainer.UpsertItemAsync(cell1, new PartitionKey(cell1.id));
        await cellsContainer.UpsertItemAsync(cell2, new PartitionKey(cell2.id));
        Console.WriteLine("✓ Seeded cells");
        
        // Seed Tenants
        var tenantsContainer = database.GetContainer("tenants");
        
        var tenant1 = new
        {
            id = "tenant-techstartup",
            tenantId = "tenant-techstartup",
            subdomain = "techstartup",
            cellBackendPool = "eastus-pool-01.stamps.com",
            cellName = "East US Cell 01",
            region = "eastus",
            tenantTier = "Startup",
            isActive = true,
            createdDate = DateTime.UtcNow.AddDays(-15).ToString("yyyy-MM-ddTHH:mm:ssZ"),
            contactEmail = "admin@techstartup.com",
            organizationName = "Tech Startup Inc",
            businessSegment = "SaaS Technology",
            complianceRequirements = new[] { "SOC2" },
            dataResidencyRequirements = new[] { "United States" },
            performanceRequirements = new
            {
                maxLatency = "100ms",
                throughputTarget = "1000rps",
                availabilityTarget = "99.9%"
            }
        };
        
        var tenant2 = new
        {
            id = "tenant-healthcorp",
            tenantId = "tenant-healthcorp",
            subdomain = "healthcorp",
            cellBackendPool = "westus-pool-01.stamps.com",
            cellName = "West US Cell 01",
            region = "westus",
            tenantTier = "Enterprise",
            isActive = true,
            createdDate = DateTime.UtcNow.AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ssZ"),
            contactEmail = "admin@healthcorp.com",
            organizationName = "HealthCorp Medical Systems",
            businessSegment = "Healthcare",
            complianceRequirements = new[] { "HIPAA", "SOC2" },
            dataResidencyRequirements = new[] { "United States" },
            performanceRequirements = new
            {
                maxLatency = "50ms",
                throughputTarget = "5000rps",
                availabilityTarget = "99.99%"
            }
        };
        
        await tenantsContainer.UpsertItemAsync(tenant1, new PartitionKey(tenant1.id));
        await tenantsContainer.UpsertItemAsync(tenant2, new PartitionKey(tenant2.id));
        Console.WriteLine("✓ Seeded tenants");
        
        // Seed Operations
        var operationsContainer = database.GetContainer("operations");
        
        var operation1 = new
        {
            id = "op-001",
            tenantId = "tenant-techstartup",
            operationId = "op-001",
            operationType = "TenantCreation",
            status = "Completed",
            cellId = "cell-eastus-01",
            startTime = DateTime.UtcNow.AddDays(-15).ToString("yyyy-MM-ddTHH:mm:ssZ"),
            endTime = DateTime.UtcNow.AddDays(-15).AddMinutes(5).ToString("yyyy-MM-ddTHH:mm:ssZ"),
            message = "Successfully created tenant techstartup in East US Cell 01"
        };
        
        var operation2 = new
        {
            id = "op-002",
            tenantId = "tenant-healthcorp",
            operationId = "op-002",
            operationType = "TenantCreation",
            status = "Completed",
            cellId = "cell-westus-01",
            startTime = DateTime.UtcNow.AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ssZ"),
            endTime = DateTime.UtcNow.AddDays(-30).AddMinutes(3).ToString("yyyy-MM-ddTHH:mm:ssZ"),
            message = "Successfully created tenant healthcorp in West US Cell 01"
        };
        
        await operationsContainer.UpsertItemAsync(operation1, new PartitionKey(operation1.id));
        await operationsContainer.UpsertItemAsync(operation2, new PartitionKey(operation2.id));
        Console.WriteLine("✓ Seeded operations");
    }
}
