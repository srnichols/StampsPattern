using Stamps.ManagementPortal.Models;
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Resources;

namespace Stamps.ManagementPortal.Services;

public interface IAzureInfrastructureService
{
    Task<InfrastructureDiscoveryResult> DiscoverInfrastructureAsync();
}

public class AzureInfrastructureService : IAzureInfrastructureService
{
    private readonly ILogger<AzureInfrastructureService> _logger;
    private readonly IConfiguration _configuration;

    public AzureInfrastructureService(ILogger<AzureInfrastructureService> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
    }

    public async Task<InfrastructureDiscoveryResult> DiscoverInfrastructureAsync()
    {
        _logger.LogInformation("Starting live Azure infrastructure discovery");

        try
        {
            // Use DefaultAzureCredential for authentication (supports various auth methods)
            var credential = new DefaultAzureCredential();
            var armClient = new ArmClient(credential);

            var cells = new List<DiscoveredCell>();
            var resources = new List<DiscoveredResource>();
            var errorMessages = new List<string>();

            // Get all subscriptions the user has access to
            var subscriptions = armClient.GetSubscriptions();

            await foreach (var subscription in subscriptions)
            {
                try
                {
                    _logger.LogInformation($"Discovering resources in subscription: {subscription.Data.DisplayName} ({subscription.Id})");

                    // Get all resource groups in this subscription
                    var resourceGroups = subscription.GetResourceGroups();

                    await foreach (var resourceGroup in resourceGroups)
                    {
                        try
                        {
                            // Check if this looks like a stamps pattern resource group
                            if (IsStampsResourceGroup(resourceGroup.Data.Name))
                            {
                                var cell = await DiscoverCellFromResourceGroup(resourceGroup);
                                if (cell != null)
                                {
                                    cells.Add(cell);
                                }

                                // Get all resources in this resource group
                                var rgResources = resourceGroup.GetGenericResources();
                                await foreach (var resource in rgResources)
                                {
                                    var discoveredResource = new DiscoveredResource
                                    {
                                        Id = resource.Id.ToString(),
                                        Name = resource.Data.Name,
                                        Type = resource.Data.ResourceType.ToString(),
                                        Location = resource.Data.Location?.Name ?? "unknown",
                                        ResourceGroup = resourceGroup.Data.Name
                                    };
                                    resources.Add(discoveredResource);
                                }
                            }
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, $"Error discovering resources in resource group {resourceGroup.Data.Name}");
                            errorMessages.Add($"Failed to discover resources in {resourceGroup.Data.Name}: {ex.Message}");
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Error accessing subscription {subscription.Data.DisplayName}");
                    errorMessages.Add($"Failed to access subscription {subscription.Data.DisplayName}: {ex.Message}");
                }
            }

            _logger.LogInformation($"Discovered {cells.Count} cells with {resources.Count} total resources");

            return new InfrastructureDiscoveryResult
            {
                Cells = cells,
                Resources = resources,
                DiscoveredAt = DateTime.UtcNow,
                TotalCells = cells.Count,
                TotalResources = resources.Count,
                Regions = resources.Select(r => r.Location).Distinct().Where(l => !string.IsNullOrEmpty(l)).ToList(),
                ResourceGroups = resources.Select(r => r.ResourceGroup).Distinct().ToList(),
                ResourceTypeBreakdown = resources.GroupBy(r => r.Type).ToDictionary(g => g.Key, g => g.Count()),
                ErrorMessages = errorMessages
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to discover Azure infrastructure");
            return new InfrastructureDiscoveryResult
            {
                Cells = new List<DiscoveredCell>(),
                Resources = new List<DiscoveredResource>(),
                DiscoveredAt = DateTime.UtcNow,
                TotalCells = 0,
                TotalResources = 0,
                Regions = new List<string>(),
                ResourceGroups = new List<string>(),
                ResourceTypeBreakdown = new Dictionary<string, int>(),
                ErrorMessages = new List<string> { $"Infrastructure discovery failed: {ex.Message}" }
            };
        }
    }

    private bool IsStampsResourceGroup(string resourceGroupName)
    {
        // Look for stamps pattern naming conventions
        var stampsPatterns = new[] { "stamps", "cell", "stamp", "tenant" };
        var lowerName = resourceGroupName.ToLowerInvariant();
        
        return stampsPatterns.Any(pattern => lowerName.Contains(pattern));
    }

    private async Task<DiscoveredCell?> DiscoverCellFromResourceGroup(ResourceGroupResource resourceGroup)
    {
        try
        {
            var rgName = resourceGroup.Data.Name;
            var location = resourceGroup.Data.Location.Name;

            // Extract cell information from resource group name and tags
            var cellId = ExtractCellId(rgName);
            var cellName = rgName.ToUpperInvariant();

            // Get resource count and types in this resource group
            var resourceTypes = new List<string>();
            var resourceCount = 0;

            var resources = resourceGroup.GetGenericResources();
            await foreach (var resource in resources)
            {
                resourceCount++;
                var resourceType = resource.Data.ResourceType.ToString();
                if (!resourceTypes.Contains(resourceType))
                {
                    resourceTypes.Add(resourceType);
                }
            }

            // Determine health status based on resource availability
            var status = DetermineHealthStatus(resourceTypes, resourceCount);

            // Calculate capacity usage (simplified heuristic based on resource count)
            var capacityUsed = Math.Min(resourceCount * 10, 100); // Rough estimate
            var capacityTotal = 100;

            return new DiscoveredCell
            {
                Id = cellId,
                Name = cellName,
                Region = location,
                Status = status,
                CapacityUsed = capacityUsed,
                CapacityTotal = capacityTotal,
                ResourceGroup = rgName,
                ResourceTypes = resourceTypes
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error creating cell from resource group {resourceGroup.Data.Name}");
            return null;
        }
    }

    private string ExtractCellId(string resourceGroupName)
    {
        // Try to extract a meaningful cell ID from the resource group name
        var lowerName = resourceGroupName.ToLowerInvariant();
        
        // Look for patterns like "stamps-eastus-001" or "cell-westus-002"
        var parts = lowerName.Split('-', '_');
        
        if (parts.Length >= 3)
        {
            // Try to find region and number
            var region = parts.FirstOrDefault(p => IsAzureRegion(p)) ?? "unknown";
            var number = parts.FirstOrDefault(p => p.All(char.IsDigit)) ?? "001";
            return $"cell-{region}-{number}";
        }
        
        return $"cell-{Guid.NewGuid().ToString()[..8]}";
    }

    private bool IsAzureRegion(string text)
    {
        var commonRegions = new[] { "eastus", "westus", "centralus", "northeurope", "westeurope", "southeastasia", "eastasia" };
        return commonRegions.Contains(text);
    }

    private string DetermineHealthStatus(List<string> resourceTypes, int resourceCount)
    {
        if (resourceCount == 0)
            return "error";
        
        // Check for critical resource types
        var hasCriticalResources = resourceTypes.Any(rt => 
            rt.Contains("Web/sites", StringComparison.OrdinalIgnoreCase) ||
            rt.Contains("Sql/servers", StringComparison.OrdinalIgnoreCase) ||
            rt.Contains("DocumentDB", StringComparison.OrdinalIgnoreCase));
        
        if (hasCriticalResources && resourceCount >= 3)
            return "healthy";
        else if (resourceCount >= 1)
            return "warning";
        else
            return "error";
    }
}

public class InfrastructureDiscoveryResult
{
    public List<DiscoveredCell> Cells { get; set; } = new();
    public List<DiscoveredResource> Resources { get; set; } = new();
    public DateTime DiscoveredAt { get; set; }
    public int TotalCells { get; set; }
    public int TotalResources { get; set; }
    public List<string> Regions { get; set; } = new();
    public List<string> ResourceGroups { get; set; } = new();
    public Dictionary<string, int> ResourceTypeBreakdown { get; set; } = new();
    public List<string> ErrorMessages { get; set; } = new();
}
