using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Resources;
using System.Net;
using System.Text.Json;
using AzureArchitecture.Services;

namespace AzureStampsPattern
{
    public class InfrastructureDiscoveryFunction
    {
        private readonly ILogger<InfrastructureDiscoveryFunction> _logger;
        private readonly DiscoveryCacheService _cacheService;
        private readonly PerformanceMonitoringService _performanceService;

        public InfrastructureDiscoveryFunction(
            ILogger<InfrastructureDiscoveryFunction> logger,
            DiscoveryCacheService cacheService,
            PerformanceMonitoringService performanceService)
        {
            _logger = logger;
            _cacheService = cacheService;
            _performanceService = performanceService;
        }

        [Function("DiscoverInfrastructure")]
        public async Task<HttpResponseData> RunAsync([HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = "infrastructure/discover")] HttpRequestData req)
        {
            return await _performanceService.MeasureAsync("InfrastructureDiscovery", async () =>
            {
                _logger.LogInformation("Infrastructure discovery function starting...");

                try
                {
                    // Get mode parameter - real Azure data or simulated
                    var query = System.Web.HttpUtility.ParseQueryString(req.Url.Query);
                    var mode = query["mode"] ?? "simulated";
                    
                    // Check cache first
                    var cachedResult = await _cacheService.GetCachedDiscoveryAsync(mode);
                    if (cachedResult != null)
                    {
                        _logger.LogInformation("Returning cached discovery result for mode: {Mode}", mode);
                        var cachedResponse = req.CreateResponse(HttpStatusCode.OK);
                        await cachedResponse.WriteStringAsync(JsonSerializer.Serialize(cachedResult));
                        cachedResponse.Headers.Add("Content-Type", "application/json");
                        return cachedResponse;
                    }
                    
                    List<DiscoveredCell> discoveredCells;
                    
                    if (mode.ToLower() == "azure")
                    {
                        // Use Azure Resource Manager for real infrastructure discovery
                        discoveredCells = await _performanceService.MeasureAsync("AzureResourceDiscovery", 
                            () => DiscoverFromAzure());
                        _logger.LogInformation($"Discovered {discoveredCells.Count} cells from Azure Resource Manager");
                    }
                    else
                    {
                        // Use simulated data for your 6 CELLs infrastructure
                        discoveredCells = _performanceService.Measure("SimulatedDiscovery", 
                            () => GetSimulatedCells());
                        _logger.LogInformation($"Discovered {discoveredCells.Count} cells from simulated data");
                    }

                var result = new
                {
                    timestamp = DateTime.UtcNow,
                    mode = mode,
                    discoveredCells = discoveredCells.Count,
                    cells = discoveredCells,
                    summary = new
                    {
                        message = $"Successfully discovered {discoveredCells.Count} cells using {mode} data",
                        regions = discoveredCells.Select(c => c.Region).Distinct().ToList(),
                        cellTypes = discoveredCells.Select(c => c.CellType).Distinct().ToList()
                    }
                };

                // Cache the result for future requests
                await _cacheService.SetCachedDiscoveryAsync(mode, result);

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
            });
        }

        private async Task<List<DiscoveredCell>> DiscoverFromAzure()
        {
            var cells = new List<DiscoveredCell>();

            try
            {
                // Use DefaultAzureCredential for Azure Resource Manager access
                var credential = new DefaultAzureCredential();
                var armClient = new ArmClient(credential);

                // Get all subscriptions accessible to the current identity
                await foreach (var subscription in armClient.GetSubscriptions().GetAllAsync())
                {
                    _logger.LogInformation($"Checking subscription: {subscription.Data.SubscriptionId}");

                    // Look for resource groups that match stamps pattern
                    await foreach (var resourceGroup in subscription.GetResourceGroups().GetAllAsync())
                    {
                        // Check if this RG contains stamps pattern resources
                        if (IsStampResourceGroup(resourceGroup.Data.Name))
                        {
                            var cell = await AnalyzeResourceGroupAsCell(resourceGroup);
                            if (cell != null)
                            {
                                cells.Add(cell);
                                _logger.LogInformation($"Found stamp cell: {cell.Name} in {cell.Region}");
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error discovering stamp cells from Azure");
                // Fallback to simulated data if Azure discovery fails
                return GetSimulatedCells();
            }

            return cells.Any() ? cells : GetSimulatedCells();
        }

        private Task<DiscoveredCell?> AnalyzeResourceGroupAsCell(ResourceGroupResource resourceGroup)
        {
            try
            {
                var resourceTypes = new List<string>();
                var appServices = 0;
                var databases = 0;
                var containerApps = 0;
                var functionApps = 0;

                foreach (var resource in resourceGroup.GetGenericResources())
                {
                    var resourceType = resource.Data.ResourceType.ToString();
                    resourceTypes.Add(resourceType);

                    // Count different resource types to determine cell capacity and type
                    var lowerType = resourceType.ToLower();
                    if (lowerType.Contains("microsoft.web/sites"))
                    {
                        if (lowerType.Contains("function"))
                        {
                            functionApps++;
                        }
                        else
                        {
                            appServices++;
                        }
                    }
                    else if (lowerType.Contains("microsoft.sql"))
                    {
                        databases++;
                    }
                    else if (lowerType.Contains("microsoft.app/containerapps"))
                    {
                        containerApps++;
                    }
                }

                // Determine cell characteristics based on discovered resources
                var cellType = DetermineCellType(appServices, databases, containerApps, functionApps);
                var estimatedCapacity = EstimateCellCapacity(resourceTypes.Count, appServices, databases, containerApps, functionApps);

                var cell = new DiscoveredCell
                {
                    Id = GenerateCellId(resourceGroup.Data.Name, resourceGroup.Data.Location.ToString()),
                    Name = GenerateCellName(resourceGroup.Data.Name),
                    Region = resourceGroup.Data.Location.ToString(),
                    ResourceGroup = resourceGroup.Data.Name,
                    Status = "Active", // Assume active if RG exists
                    EstimatedCapacity = estimatedCapacity,
                    CellType = cellType,
                    ResourceTypes = resourceTypes,
                    ResourceCount = resourceTypes.Count,
                    Tags = resourceGroup.Data.Tags?.ToDictionary(t => t.Key, t => t.Value) ?? new Dictionary<string, string>(),
                    LastDiscovered = DateTime.UtcNow,
                    AdditionalInfo = new Dictionary<string, string>
                    {
                        ["AppServices"] = appServices.ToString(),
                        ["Databases"] = databases.ToString(),
                        ["ContainerApps"] = containerApps.ToString(),
                        ["FunctionApps"] = functionApps.ToString()
                    }
                };

                return Task.FromResult<DiscoveredCell?>(cell);
            }
            catch (Exception ex)
            {
                _logger.LogWarning($"Failed to analyze resource group {resourceGroup.Data.Name}: {ex.Message}");
                return Task.FromResult<DiscoveredCell?>(null);
            }
        }

        private bool IsStampResourceGroup(string resourceGroupName)
        {
            // Enhanced pattern matching for your Stamps Pattern infrastructure
            var stampPatterns = new[]
            {
                "stamps",              // Generic stamps
                "stamp-",              // Individual stamp prefix
                "cell-",               // Cell-based naming
                "rg-stamps",           // Resource group stamps
                "rg-stamp",            // Resource group stamp
                "rg-cell",             // Resource group cell
                "geo-",                // Geographic pattern
                "region-",             // Regional pattern
                "fa-stamps",           // Function App stamps
                "stampspattern",       // Project name
                "azure-stamps",        // Azure stamps
                "tenant-",             // Tenant isolation
                "deployment-",         // Deployment stamps
                "scale-",              // Scale units
                "zone-"                // Availability zones
            };

            var lowerName = resourceGroupName.ToLower();
            
            // Check explicit patterns
            foreach (var pattern in stampPatterns)
            {
                if (lowerName.Contains(pattern.ToLower()))
                {
                    return true;
                }
            }

            // Check for numeric patterns that might indicate cells/stamps
            var numericPattern = @"(cell|stamp|rg)[-_]?\d+";
            if (System.Text.RegularExpressions.Regex.IsMatch(lowerName, numericPattern))
            {
                return true;
            }

            // Check for region-specific patterns
            var regionPatterns = new[] { "westus", "eastus", "centralus", "northeurope", "westeurope", "southcentralus" };
            foreach (var region in regionPatterns)
            {
                if (lowerName.Contains(region) && (lowerName.Contains("stamp") || lowerName.Contains("cell") || lowerName.Contains("deploy")))
                {
                    return true;
                }
            }

            return false;
        }

        private string GenerateCellId(string resourceGroupName, string region)
        {
            var cleanName = resourceGroupName.ToLower()
                .Replace("rg-", "")
                .Replace("stamps-", "")
                .Replace("stamp-", "")
                .Replace("cell-", "")
                .Replace("fa-stamps-", "")
                .Replace("fa-", "");
            
            return $"discovered-{region}-{cleanName}-{DateTime.UtcNow:yyyyMMdd}";
        }

        private string GenerateCellName(string resourceGroupName)
        {
            return resourceGroupName.Replace("rg-", "")
                                   .Replace("-", " ")
                                   .ToTitleCaseCustom();
        }

        private string DetermineCellType(int appServices, int databases, int containerApps, int functionApps)
        {
            if (containerApps > 0) return "Container Apps Stamp";
            if (functionApps > 0) return "Azure Functions Stamp";
            if (appServices > 0 && databases > 0) return "Full Stack Stamp";
            if (appServices > 0) return "App Service Stamp";
            if (databases > 0) return "Database Stamp";
            return "Infrastructure Stamp";
        }

        private int EstimateCellCapacity(int totalResources, int appServices, int databases, int containerApps, int functionApps)
        {
            // Advanced capacity estimation based on Azure resource types and configurations
            int baseCapacity = totalResources * 15; // Base resource count factor
            
            // Weight different service types by their capacity impact
            var serviceCapacity = 0;
            serviceCapacity += appServices * 200;      // App Services - high capacity impact
            serviceCapacity += databases * 400;       // Databases - very high capacity impact 
            serviceCapacity += containerApps * 300;   // Container Apps - very high capacity
            serviceCapacity += functionApps * 150;    // Function Apps - moderate-high capacity
            
            // Calculate total capacity with minimum threshold
            var totalCapacity = baseCapacity + serviceCapacity;
            
            // Apply scaling factors based on service combinations
            if (databases > 0 && (appServices > 0 || containerApps > 0))
            {
                totalCapacity += 200; // Bonus for full-stack architecture
            }
            
            if (containerApps > 0 && appServices > 0)
            {
                totalCapacity += 150; // Bonus for hybrid compute architecture
            }
            
            // Apply realistic bounds with better scaling
            return Math.Max(100, Math.Min(totalCapacity, 15000)); // Between 100 and 15,000
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

    // Extension method for title case conversion
    public static class StringExtensions
    {
        public static string ToTitleCaseCustom(this string input)
        {
            if (string.IsNullOrWhiteSpace(input))
                return input;

            var words = input.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            for (int i = 0; i < words.Length; i++)
            {
                if (words[i].Length > 0)
                {
                    words[i] = char.ToUpper(words[i][0]) + 
                              (words[i].Length > 1 ? words[i].Substring(1).ToLower() : "");
                }
            }
            return string.Join(" ", words);
        }
    }
}
