using Stamps.ManagementPortal.Models;
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Resources;
using Azure.Core;

namespace Stamps.ManagementPortal.Services;

public interface ICosmosDiscoveryService
{
    Task<List<Tenant>> DiscoverTenantsAsync();
    Task<List<Cell>> DiscoverCellsAsync();
    Task SynchronizeDataAsync();
}

public class CosmosDiscoveryService : ICosmosDiscoveryService
{
    private readonly ILogger<CosmosDiscoveryService> _logger;
    private readonly IConfiguration _configuration;
    private readonly IDataService _dataService;
    private readonly ArmClient _armClient;

    public CosmosDiscoveryService(
        ILogger<CosmosDiscoveryService> logger, 
        IConfiguration configuration,
        IDataService dataService)
    {
        _logger = logger;
        _configuration = configuration;
        _dataService = dataService;
        _armClient = new ArmClient(new DefaultAzureCredential());
    }

    public async Task<List<Tenant>> DiscoverTenantsAsync()
    {
        _logger.LogInformation("Discovering live tenants from Azure infrastructure");

        try
        {
            var credential = new DefaultAzureCredential();
            var armClient = new ArmClient(credential);
            var tenants = new List<Tenant>();

            var subscriptions = armClient.GetSubscriptions();
            await foreach (var subscription in subscriptions)
            {
                try
                {
                    var resourceGroups = subscription.GetResourceGroups();
                    await foreach (var resourceGroup in resourceGroups)
                    {
                        // Look for tenant-specific resource groups
                        if (IsTenantResourceGroup(resourceGroup.Data.Name))
                        {
                            var tenant = await ExtractTenantFromResourceGroup(resourceGroup);
                            if (tenant != null)
                            {
                                tenants.Add(tenant);
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Error discovering tenants in subscription {subscription.Data.DisplayName}");
                }
            }

            _logger.LogInformation($"Discovered {tenants.Count} live tenants");
            return tenants;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to discover live tenants");
            return new List<Tenant>();
        }
    }

    public async Task<List<Cell>> DiscoverCellsAsync()
    {
        _logger.LogInformation("Discovering live cells from Azure infrastructure");

        try
        {
            var credential = new DefaultAzureCredential();
            var armClient = new ArmClient(credential);
            var cells = new List<Cell>();

            var subscriptions = armClient.GetSubscriptions();
            await foreach (var subscription in subscriptions)
            {
                try
                {
                    var resourceGroups = subscription.GetResourceGroups();
                    await foreach (var resourceGroup in resourceGroups)
                    {
                        // Look for cell/stamp resource groups
                        if (IsCellResourceGroup(resourceGroup.Data.Name))
                        {
                            var cell = await ExtractCellFromResourceGroup(resourceGroup);
                            if (cell != null)
                            {
                                cells.Add(cell);
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Error discovering cells in subscription {subscription.Data.DisplayName}");
                }
            }

            _logger.LogInformation($"Discovered {cells.Count} live cells");
            return cells;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to discover live cells");
            return new List<Cell>();
        }
    }

    public async Task SynchronizeDataAsync()
    {
        _logger.LogInformation("Starting live data synchronization with Cosmos DB");

        try
        {
            // Discover live data from Azure
            var discoveredTenants = await DiscoverTenantsAsync();
            var discoveredCells = await DiscoverCellsAsync();

            // Get existing data from Cosmos DB
            var existingTenants = await _dataService.GetTenantsAsync();
            var existingCells = await _dataService.GetCellsAsync();

            // Synchronize tenants
            foreach (var tenant in discoveredTenants)
            {
                var existing = existingTenants.FirstOrDefault(t => t.Id == tenant.Id);
                if (existing == null)
                {
                    await _dataService.CreateTenantAsync(tenant);
                    _logger.LogInformation($"Created new tenant: {tenant.DisplayName}");
                }
                else if (!TenantsEqual(existing, tenant))
                {
                    await _dataService.UpdateTenantAsync(tenant);
                    _logger.LogInformation($"Updated tenant: {tenant.DisplayName}");
                }
            }

            // Synchronize cells
            foreach (var cell in discoveredCells)
            {
                var existing = existingCells.FirstOrDefault(c => c.Id == cell.Id);
                if (existing == null)
                {
                    await _dataService.CreateCellAsync(cell);
                    _logger.LogInformation($"Created new cell: {cell.Id}");
                }
                else if (!CellsEqual(existing, cell))
                {
                    await _dataService.UpdateCellAsync(cell);
                    _logger.LogInformation($"Updated cell: {cell.Id}");
                }
            }

            _logger.LogInformation($"Synchronized {discoveredTenants.Count} tenants and {discoveredCells.Count} cells");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to synchronize live data with Cosmos DB");
            throw;
        }
    }

    private bool IsTenantResourceGroup(string resourceGroupName)
    {
        var lowerName = resourceGroupName.ToLowerInvariant();
        return lowerName.Contains("tenant") || 
               lowerName.Contains("customer") ||
               (lowerName.Contains("app") && !lowerName.Contains("cell") && !lowerName.Contains("stamp"));
    }

    private bool IsCellResourceGroup(string resourceGroupName)
    {
        var lowerName = resourceGroupName.ToLowerInvariant();
        return lowerName.Contains("cell") || 
               lowerName.Contains("stamp") || 
               lowerName.Contains("region");
    }

    private async Task<Tenant?> ExtractTenantFromResourceGroup(ResourceGroupResource resourceGroup)
    {
        try
        {
            var rgName = resourceGroup.Data.Name;
            var tags = resourceGroup.Data.Tags;

            // Extract tenant information from resource group name and tags
            var tenantId = ExtractTenantId(rgName, tags);
            var displayName = ExtractDisplayName(rgName, tags);
            var domain = ExtractDomain(rgName, tags);
            var tier = ExtractTier(tags);
            var cellId = await DetermineCellId(resourceGroup);

            return new Tenant(
                Id: tenantId,
                DisplayName: displayName,
                Domain: domain,
                Tier: tier,
                Status: "active",
                CellId: cellId
            );
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error extracting tenant from resource group {resourceGroup.Data.Name}");
            return null;
        }
    }

    private async Task<Cell?> ExtractCellFromResourceGroup(ResourceGroupResource resourceGroup)
    {
        try
        {
            var rgName = resourceGroup.Data.Name;
            var location = resourceGroup.Data.Location.Name;
            var tags = resourceGroup.Data.Tags;

            // Extract cell information
            var cellId = ExtractCellId(rgName);
            var region = location;
            var availabilityZone = ExtractAvailabilityZone(rgName, tags);
            var status = await DetermineCellHealth(resourceGroup);
            var (capacityUsed, capacityTotal) = await CalculateCellCapacity(resourceGroup);

            return new Cell(
                Id: cellId,
                Region: region,
                AvailabilityZone: availabilityZone,
                Status: status,
                CapacityUsed: capacityUsed,
                CapacityTotal: capacityTotal
            );
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error extracting cell from resource group {resourceGroup.Data.Name}");
            return null;
        }
    }

    private string ExtractTenantId(string resourceGroupName, IDictionary<string, string>? tags)
    {
        // Try to get from tags first
        if (tags?.TryGetValue("tenantId", out var tenantId) == true && !string.IsNullOrEmpty(tenantId))
            return tenantId;

        if (tags?.TryGetValue("tenant", out tenantId) == true && !string.IsNullOrEmpty(tenantId))
            return tenantId;

        // Extract from resource group name
        var parts = resourceGroupName.ToLowerInvariant().Split('-', '_');
        var tenantPart = parts.FirstOrDefault(p => p.Contains("tenant"));
        if (tenantPart != null)
        {
            return tenantPart.Replace("tenant", "").Trim();
        }

        // Generate a unique ID based on resource group name
        return $"tenant-{resourceGroupName.ToLowerInvariant().Replace("_", "-")}";
    }

    private string ExtractDisplayName(string resourceGroupName, IDictionary<string, string>? tags)
    {
        if (tags?.TryGetValue("displayName", out var displayName) == true && !string.IsNullOrEmpty(displayName))
            return displayName;

        if (tags?.TryGetValue("tenantName", out displayName) == true && !string.IsNullOrEmpty(displayName))
            return displayName;

        // Extract from resource group name
        var cleaned = resourceGroupName
            .Replace("tenant-", "", StringComparison.OrdinalIgnoreCase)
            .Replace("_", " ")
            .Replace("-", " ");
        
        return System.Globalization.CultureInfo.CurrentCulture.TextInfo.ToTitleCase(cleaned);
    }

    private string ExtractDomain(string resourceGroupName, IDictionary<string, string>? tags)
    {
        if (tags?.TryGetValue("domain", out var domain) == true && !string.IsNullOrEmpty(domain))
            return domain;

        // Try to extract from resource group name or generate a default
        var parts = resourceGroupName.ToLowerInvariant().Split('-', '_');
        var tenantName = parts.FirstOrDefault(p => !string.IsNullOrEmpty(p) && p != "tenant" && p != "rg");
        
        return $"{tenantName ?? "example"}.com";
    }

    private string ExtractTier(IDictionary<string, string>? tags)
    {
        if (tags?.TryGetValue("tier", out var tier) == true && !string.IsNullOrEmpty(tier))
            return tier;

        return "standard"; // Default tier
    }

    private async Task<string> DetermineCellId(ResourceGroupResource resourceGroup)
    {
        // Look for related cell/stamp resource groups in the same region
        var location = resourceGroup.Data.Location.Name;
        var subscriptionId = resourceGroup.Id.SubscriptionId;
        var subscription = _armClient.GetSubscriptionResource(new ResourceIdentifier($"/subscriptions/{subscriptionId}"));
        
        var resourceGroups = subscription.GetResourceGroups();
        foreach (var rg in resourceGroups)
        {
            if (IsCellResourceGroup(rg.Data.Name) && rg.Data.Location.Name == location)
            {
                return ExtractCellId(rg.Data.Name);
            }
        }

        // Generate a default cell ID
        return $"cell-{location}-001";
    }

    private string ExtractCellId(string resourceGroupName)
    {
        var lowerName = resourceGroupName.ToLowerInvariant();
        var parts = lowerName.Split('-', '_');
        
        // Look for patterns like "cell-eastus-001" or "stamp-westus-002"
        if (parts.Length >= 3)
        {
            var prefix = parts.FirstOrDefault(p => p == "cell" || p == "stamp") ?? "cell";
            var region = parts.FirstOrDefault(p => IsAzureRegion(p)) ?? "unknown";
            var number = parts.FirstOrDefault(p => p.All(char.IsDigit)) ?? "001";
            return $"{prefix}-{region}-{number}";
        }
        
        return $"cell-{Guid.NewGuid().ToString()[..8]}";
    }

    private string ExtractAvailabilityZone(string resourceGroupName, IDictionary<string, string>? tags)
    {
        if (tags?.TryGetValue("availabilityZone", out var az) == true && !string.IsNullOrEmpty(az))
            return az;

        // Extract from name or default
        var parts = resourceGroupName.ToLowerInvariant().Split('-', '_');
        var number = parts.FirstOrDefault(p => p.All(char.IsDigit));
        return number ?? "1";
    }

    private async Task<string> DetermineCellHealth(ResourceGroupResource resourceGroup)
    {
        try
        {
            var resources = resourceGroup.GetGenericResources();
            var resourceCount = 0;
            var criticalResourceCount = 0;

            foreach (var resource in resources)
            {
                resourceCount++;
                var resourceType = resource.Data.ResourceType.ToString();
                if (IsCriticalResourceType(resourceType))
                {
                    criticalResourceCount++;
                }
            }

            if (resourceCount == 0)
                return "error";
            
            if (criticalResourceCount >= 2 && resourceCount >= 3)
                return "healthy";
            else if (resourceCount >= 1)
                return "warning";
            else
                return "error";
        }
        catch
        {
            return "unknown";
        }
    }

    private async Task<(int used, int total)> CalculateCellCapacity(ResourceGroupResource resourceGroup)
    {
        try
        {
            var resources = resourceGroup.GetGenericResources();
            var resourceCount = 0;

            foreach (var resource in resources)
            {
                resourceCount++;
            }

            // Simplified capacity calculation based on resource count and types
            var capacityUsed = Math.Min(resourceCount * 5, 100);
            var capacityTotal = 100;

            return (capacityUsed, capacityTotal);
        }
        catch
        {
            return (0, 100);
        }
    }

    private bool IsAzureRegion(string text)
    {
        var commonRegions = new[] { 
            "eastus", "westus", "centralus", "northcentralus", "southcentralus",
            "eastus2", "westus2", "westus3", "northeurope", "westeurope", 
            "southeastasia", "eastasia", "australiaeast", "australiasoutheast",
            "brazilsouth", "canadacentral", "canadaeast", "chinaeast", "chinanorth",
            "francecentral", "germanywestcentral", "japaneast", "japanwest",
            "koreacentral", "norwayeast", "southafricanorth", "swedencentral",
            "switzerlandnorth", "uaenorth", "uksouth", "ukwest"
        };
        return commonRegions.Contains(text);
    }

    private bool IsCriticalResourceType(string resourceType)
    {
        var criticalTypes = new[]
        {
            "Microsoft.Web/sites",
            "Microsoft.Sql/servers",
            "Microsoft.DocumentDB/databaseAccounts",
            "Microsoft.Storage/storageAccounts",
            "Microsoft.Cache/Redis",
            "Microsoft.ServiceBus/namespaces"
        };
        
        return criticalTypes.Any(ct => resourceType.Contains(ct, StringComparison.OrdinalIgnoreCase));
    }

    private bool TenantsEqual(Tenant existing, Tenant discovered)
    {
        return existing.DisplayName == discovered.DisplayName &&
               existing.Domain == discovered.Domain &&
               existing.Tier == discovered.Tier &&
               existing.Status == discovered.Status &&
               existing.CellId == discovered.CellId;
    }

    private bool CellsEqual(Cell existing, Cell discovered)
    {
        return existing.Region == discovered.Region &&
               existing.AvailabilityZone == discovered.AvailabilityZone &&
               existing.Status == discovered.Status &&
               existing.CapacityUsed == discovered.CapacityUsed &&
               existing.CapacityTotal == discovered.CapacityTotal;
    }
}