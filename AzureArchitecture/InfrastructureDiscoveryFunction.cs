using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using System.Net;
using System.Text.Json;

namespace AzureStampsPattern
{
    public class InfrastructureDiscoveryFunction
    {
        private readonly ILogger<InfrastructureDiscoveryFunction> _logger;

        public InfrastructureDiscoveryFunction(ILogger<InfrastructureDiscoveryFunction> logger)
        {
            _logger = logger;
        }

        [Function("DiscoverInfrastructure")]
        public async Task<HttpResponseData> RunAsync([HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = "infrastructure/discover")] HttpRequestData req)
        {
            _logger.LogInformation("Infrastructure discovery function starting...");

            try
            {
                // Simulated data for your 6 CELLs infrastructure across 2 regions
                var discoveredCells = GetSimulatedCells();
                _logger.LogInformation($"Discovered {discoveredCells.Count} cells from simulated data");

                var result = new
                {
                    timestamp = DateTime.UtcNow,
                    discoveredCells = discoveredCells.Count,
                    cells = discoveredCells,
                    summary = new
                    {
                        message = $"Successfully discovered {discoveredCells.Count} cells using simulated data",
                        regions = discoveredCells.Select(c => c.Region).Distinct().ToList(),
                        cellTypes = discoveredCells.Select(c => c.CellType).Distinct().ToList()
                    }
                };

                var response = req.CreateResponse(HttpStatusCode.OK);
                response.Headers.Add("Content-Type", "application/json; charset=utf-8");
                await response.WriteAsJsonAsync(result);
                return response;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during infrastructure discovery");
                
                var errorResult = new
                {
                    error = "Infrastructure discovery failed",
                    message = ex.Message,
                    timestamp = DateTime.UtcNow
                };

                var response = req.CreateResponse(HttpStatusCode.InternalServerError);
                response.Headers.Add("Content-Type", "application/json; charset=utf-8");
                await response.WriteAsJsonAsync(errorResult);
                return response;
            }
        }

        private List<DiscoveredCell> GetSimulatedCells()
        {
            return new List<DiscoveredCell>
            {
                new DiscoveredCell
                {
                    Id = "discovered-westus2-cell-001",
                    Name = "West US 2 Primary Cell",
                    Region = "westus2",
                    ResourceGroup = "rg-stamps-westus2-001",
                    Status = "Active",
                    EstimatedCapacity = 500,
                    CellType = "Azure Functions Stamp",
                    ResourceTypes = new List<string> { "Microsoft.Web/sites", "Microsoft.Storage/storageAccounts" },
                    ResourceCount = 2,
                    Tags = new Dictionary<string, string> { { "Environment", "Production" }, { "CellType", "Primary" } },
                    AdditionalInfo = new Dictionary<string, string> { { "FunctionApps", "1" }, { "StorageAccounts", "1" } },
                    LastDiscovered = DateTime.UtcNow
                },
                new DiscoveredCell
                {
                    Id = "discovered-westus2-cell-002",
                    Name = "West US 2 Secondary Cell",
                    Region = "westus2",
                    ResourceGroup = "rg-stamps-westus2-002",
                    Status = "Active",
                    EstimatedCapacity = 450,
                    CellType = "Container Apps Stamp",
                    ResourceTypes = new List<string> { "Microsoft.App/containerApps", "Microsoft.Storage/storageAccounts" },
                    ResourceCount = 3,
                    Tags = new Dictionary<string, string> { { "Environment", "Production" }, { "CellType", "Secondary" } },
                    AdditionalInfo = new Dictionary<string, string> { { "ContainerApps", "2" }, { "StorageAccounts", "1" } },
                    LastDiscovered = DateTime.UtcNow
                },
                new DiscoveredCell
                {
                    Id = "discovered-westus2-cell-003",
                    Name = "West US 2 Tertiary Cell",
                    Region = "westus2",
                    ResourceGroup = "rg-stamps-westus2-003",
                    Status = "Active",
                    EstimatedCapacity = 600,
                    CellType = "Full Stack Stamp",
                    ResourceTypes = new List<string> { "Microsoft.Web/sites", "Microsoft.Sql/servers", "Microsoft.Storage/storageAccounts" },
                    ResourceCount = 4,
                    Tags = new Dictionary<string, string> { { "Environment", "Production" }, { "CellType", "Tertiary" } },
                    AdditionalInfo = new Dictionary<string, string> { { "AppServices", "1" }, { "Databases", "1" }, { "StorageAccounts", "2" } },
                    LastDiscovered = DateTime.UtcNow
                },
                new DiscoveredCell
                {
                    Id = "discovered-eastus-cell-001",
                    Name = "East US Primary Cell",
                    Region = "eastus",
                    ResourceGroup = "rg-stamps-eastus-001",
                    Status = "Active",
                    EstimatedCapacity = 750,
                    CellType = "Full Stack Stamp",
                    ResourceTypes = new List<string> { "Microsoft.Web/sites", "Microsoft.Sql/servers", "Microsoft.Storage/storageAccounts" },
                    ResourceCount = 5,
                    Tags = new Dictionary<string, string> { { "Environment", "Production" }, { "CellType", "Primary" } },
                    AdditionalInfo = new Dictionary<string, string> { { "AppServices", "2" }, { "Databases", "1" }, { "StorageAccounts", "2" } },
                    LastDiscovered = DateTime.UtcNow
                },
                new DiscoveredCell
                {
                    Id = "discovered-eastus-cell-002",
                    Name = "East US Secondary Cell",
                    Region = "eastus",
                    ResourceGroup = "rg-stamps-eastus-002",
                    Status = "Active",
                    EstimatedCapacity = 650,
                    CellType = "Azure Functions Stamp",
                    ResourceTypes = new List<string> { "Microsoft.Web/sites", "Microsoft.Storage/storageAccounts", "Microsoft.KeyVault/vaults" },
                    ResourceCount = 4,
                    Tags = new Dictionary<string, string> { { "Environment", "Production" }, { "CellType", "Secondary" } },
                    AdditionalInfo = new Dictionary<string, string> { { "FunctionApps", "2" }, { "StorageAccounts", "1" }, { "KeyVaults", "1" } },
                    LastDiscovered = DateTime.UtcNow
                },
                new DiscoveredCell
                {
                    Id = "discovered-eastus-cell-003",
                    Name = "East US Tertiary Cell",
                    Region = "eastus",
                    ResourceGroup = "rg-stamps-eastus-003",
                    Status = "Active",
                    EstimatedCapacity = 550,
                    CellType = "Container Apps Stamp",
                    ResourceTypes = new List<string> { "Microsoft.App/containerApps", "Microsoft.Storage/storageAccounts", "Microsoft.Insights/components" },
                    ResourceCount = 3,
                    Tags = new Dictionary<string, string> { { "Environment", "Production" }, { "CellType", "Tertiary" } },
                    AdditionalInfo = new Dictionary<string, string> { { "ContainerApps", "1" }, { "StorageAccounts", "1" }, { "ApplicationInsights", "1" } },
                    LastDiscovered = DateTime.UtcNow
                }
            };
        }
    }

    // Data models for infrastructure discovery
    public class DiscoveredCell
    {
        public string Id { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Region { get; set; } = string.Empty;
        public string ResourceGroup { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public int EstimatedCapacity { get; set; }
        public string CellType { get; set; } = string.Empty;
        public List<string> ResourceTypes { get; set; } = new();
        public int ResourceCount { get; set; }
        public Dictionary<string, string> Tags { get; set; } = new();
        public Dictionary<string, string> AdditionalInfo { get; set; } = new();
        public DateTime LastDiscovered { get; set; }
    }
}
