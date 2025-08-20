
using Stamps.ManagementPortal.Models;
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Resources;
using Stamps.ManagementPortal.GraphQL;
using HotChocolate.Subscriptions;

namespace Stamps.ManagementPortal.Services
{
    public interface IAzureInfrastructureService
    {
        Task<InfrastructureDiscoveryResult> DiscoverInfrastructureAsync();
    }

    public class AzureInfrastructureService : IAzureInfrastructureService
    {
        private readonly ILogger<AzureInfrastructureService> _logger;
        private readonly IConfiguration _configuration;
        private readonly ITaskEventPublisher _taskEventPublisher;

        public AzureInfrastructureService(ILogger<AzureInfrastructureService> logger, IConfiguration configuration, ITaskEventPublisher taskEventPublisher)
        {
            _logger = logger;
            _configuration = configuration;
            _taskEventPublisher = taskEventPublisher;
        }

    public async Task<InfrastructureDiscoveryResult> DiscoverInfrastructureAsync()
    {
        _logger.LogInformation("Starting live Azure infrastructure discovery");

        await _taskEventPublisher.PublishTaskEventAsync(new TaskEvent {
            Id = Guid.NewGuid().ToString(),
            Status = "Started",
            Message = "Infrastructure discovery started",
            Timestamp = DateTime.UtcNow
        });

            await foreach (var subscription in subscriptions)
            {
                try
                {
                    _logger.LogInformation($"Discovering resources in subscription: {subscription.Data.DisplayName} ({subscription.Id})");
                    await _taskEventPublisher.PublishTaskEventAsync(new TaskEvent {
                        Id = Guid.NewGuid().ToString(),
                        Status = "InProgress",
                        Message = $"Discovering resources in subscription: {subscription.Data.DisplayName}",
                        Timestamp = DateTime.UtcNow
                    });

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
                                foreach (var resource in rgResources)
                                {
                                    var discoveredResource = new DiscoveredResource
                                    {
                                        Id = resource.Id.ToString(),
                                        Name = resource.Data.Name,
                                        Type = resource.Data.ResourceType.ToString(),
                                        Location = resource.Data.Location.Name,
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
                            // Publish error event
                            await _taskEventPublisher.PublishTaskEventAsync(new TaskEvent {
                                Id = Guid.NewGuid().ToString(),
                                Status = "Error",
                                Message = $"Failed to discover resources in {resourceGroup.Data.Name}: {ex.Message}",
                                Timestamp = DateTime.UtcNow
                            });
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Error accessing subscription {subscription.Data.DisplayName}");
                    errorMessages.Add($"Failed to access subscription {subscription.Data.DisplayName}: {ex.Message}");
                    // Publish error event
                    await _taskEventPublisher.PublishTaskEventAsync(new TaskEvent {
                        Id = Guid.NewGuid().ToString(),
                        Status = "Error",
                        Message = $"Failed to access subscription {subscription.Data.DisplayName}: {ex.Message}",
                        Timestamp = DateTime.UtcNow
                    });
                }
            }

            _logger.LogInformation($"Discovered {cells.Count} cells with {resources.Count} total resources");
            await _taskEventPublisher.PublishTaskEventAsync(new TaskEvent {
                Id = Guid.NewGuid().ToString(),
                Status = "Completed",
                Message = $"Discovery completed: {cells.Count} cells, {resources.Count} resources.",
                Timestamp = DateTime.UtcNow
            });

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
            foreach (var resource in resources)
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

    private InfrastructureDiscoveryResult CreateSimulatedDiscoveryResult()
    {
        _logger.LogInformation("Creating simulated discovery result for local development");
        
        var simulatedCells = new List<DiscoveredCell>
        {
            new DiscoveredCell
            {
                Id = "cell-eastus-001",
                Name = "STAMPS-EASTUS-001",
                Region = "eastus",
                Status = "healthy",
                CapacityUsed = 65,
                CapacityTotal = 100,
                ResourceGroup = "rg-stamps-eastus-001",
                ResourceTypes = new List<string> { "Microsoft.Web/sites", "Microsoft.Sql/servers", "Microsoft.Storage/storageAccounts" }
            },
            new DiscoveredCell
            {
                Id = "cell-westus-001", 
                Name = "STAMPS-WESTUS-001",
                Region = "westus",
                Status = "healthy",
                CapacityUsed = 45,
                CapacityTotal = 100,
                ResourceGroup = "rg-stamps-westus-001",
                ResourceTypes = new List<string> { "Microsoft.Web/sites", "Microsoft.Sql/servers", "Microsoft.Storage/storageAccounts" }
            },
            new DiscoveredCell
            {
                Id = "cell-westeurope-001",
                Name = "STAMPS-WESTEUROPE-001", 
                Region = "westeurope",
                Status = "warning",
                CapacityUsed = 85,
                CapacityTotal = 100,
                ResourceGroup = "rg-stamps-westeurope-001",
                ResourceTypes = new List<string> { "Microsoft.Web/sites", "Microsoft.Storage/storageAccounts" }
            }
        };

        var simulatedResources = new List<DiscoveredResource>();
        foreach (var cell in simulatedCells)
        {
            simulatedResources.AddRange(new[]
            {
                new DiscoveredResource 
                { 
                    Id = $"/subscriptions/simulation/resourceGroups/{cell.ResourceGroup}/providers/Microsoft.Web/sites/app-{cell.Region}",
                    Name = $"app-{cell.Region}",
                    Type = "Microsoft.Web/sites",
                    Location = cell.Region,
                    ResourceGroup = cell.ResourceGroup
                },
                new DiscoveredResource
                {
                    Id = $"/subscriptions/simulation/resourceGroups/{cell.ResourceGroup}/providers/Microsoft.Storage/storageAccounts/st{cell.Region}001",
                    Name = $"st{cell.Region}001", 
                    Type = "Microsoft.Storage/storageAccounts",
                    Location = cell.Region,
                    ResourceGroup = cell.ResourceGroup
                }
            });
        }

        return new InfrastructureDiscoveryResult
        {
            Cells = simulatedCells,
            Resources = simulatedResources,
            DiscoveredAt = DateTime.UtcNow,
            TotalCells = simulatedCells.Count,
            TotalResources = simulatedResources.Count,
            Regions = simulatedCells.Select(c => c.Region).Distinct().ToList(),
            ResourceGroups = simulatedCells.Select(c => c.ResourceGroup).Distinct().ToList(),
            ResourceTypeBreakdown = simulatedResources.GroupBy(r => r.Type).ToDictionary(g => g.Key, g => g.Count()),
            ErrorMessages = new List<string> { "Using simulated data for local development - Azure CLI not configured" }
        };
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
