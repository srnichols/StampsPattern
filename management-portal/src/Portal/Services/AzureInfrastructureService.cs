using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Resources;
using Azure.ResourceManager.Compute;
using Azure.ResourceManager.AppService;
using Azure.ResourceManager.CosmosDB;
using Azure.ResourceManager.Storage;
using Azure.ResourceManager.ContainerInstance;
using Azure.ResourceManager.Sql;
using Stamps.ManagementPortal.Models;

namespace Stamps.ManagementPortal.Services
{
    public class AzureInfrastructureService
    {
        private readonly ILogger<AzureInfrastructureService> _logger;
        private readonly IConfiguration _configuration;
    private ArmClient? _armClient;
        private bool _armClientInitialized = false;
        private readonly List<string> _candidateClientIds = new()
        {
            // Known client IDs for mi-stamps-mgmt instances (will try these if no explicit config)
            "b1a030a7-2623-4c34-839f-9f37a9c4b303",
            "089c14a4-e28f-417b-9c92-5d92deacb9ff"
        };
        
        // Target subscriptions for live data
        private readonly List<string> _targetSubscriptions = new()
        {
            "2fb123ca-e419-4838-9b44-c2eb71a21769", // MCAPS-Hybrid-REQ-101203-2024-scnichol-Host
            "480cb033-9a92-4912-9d30-c6b7bf795a87"  // MCAPS-Hybrid-REQ-103709-2024-scnichol-Hub
        };
        
        // Expected regions for the stamps pattern
        private readonly List<string> _targetRegions = new()
        {
            "westus2",
            "westus3"
        };

        public AzureInfrastructureService(ILogger<AzureInfrastructureService> logger, IConfiguration configuration)
        {
            _logger = logger;
            _configuration = configuration;
            
            // Delay ArmClient initialization until we can pick a working credential at runtime
            _armClient = null!; // initialized lazily in DiscoverInfrastructureAsync
         }

        private async Task EnsureArmClientInitializedAsync()
        {
            if (_armClientInitialized)
                return;

            // Allow explicit override via configuration or environment variable
            var configuredClientId = _configuration["AzureManagedIdentityClientId"] ?? Environment.GetEnvironmentVariable("AzureManagedIdentityClientId");
            var candidates = new List<string>();
            if (!string.IsNullOrWhiteSpace(configuredClientId)) candidates.Add(configuredClientId);
            candidates.AddRange(_candidateClientIds);

            // Finally include a null entry which means use system/default credential without specifying a client id
            candidates.Add(null!);

            foreach (var candidate in candidates)
            {
                try
                {
                    var options = new DefaultAzureCredentialOptions();
                    if (!string.IsNullOrWhiteSpace(candidate))
                    {
                        options.ManagedIdentityClientId = candidate;
                        _logger.LogInformation("Trying managed identity client id: {ClientId}", candidate);
                    }
                    else
                    {
                        _logger.LogInformation("Trying DefaultAzureCredential without a user-assigned client id");
                    }

                    var credential = new DefaultAzureCredential(options);
                    var arm = new ArmClient(credential);

                    // Quick smoke test: enumerate subscriptions (first page) to validate the credential
                    var subscriptionFound = false;
                    await foreach (var _sub in arm.GetSubscriptions().GetAllAsync())
                    {
                        subscriptionFound = true;
                        break;
                    }
                    if (subscriptionFound)
                    {
                        // If we got here, the credential worked
                        _armClient = arm;
                        _armClientInitialized = true;
                        _logger.LogInformation("Selected managed identity credential: {ClientId}", candidate ?? "(default)");
                        return;
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Credential attempt failed for client id '{ClientId}'", candidate ?? "(default)");
                    // try next candidate
                }
            }

            throw new InvalidOperationException("Unable to authenticate with any candidate managed identity or default credential.");
        }

        public async Task<AzureInfrastructureData> DiscoverInfrastructureAsync()
        {
            _logger.LogInformation("Starting Azure infrastructure discovery for stamps pattern...");
            _logger.LogInformation($"Target subscriptions: {string.Join(", ", _targetSubscriptions)}");
            _logger.LogInformation($"Target regions: {string.Join(", ", _targetRegions)}");
            
            var result = new AzureInfrastructureData
            {
                DiscoveredAt = DateTime.UtcNow,
                Cells = new List<DiscoveredCell>(),
                Resources = new List<DiscoveredResource>(),
                Regions = new List<string>(),
                ResourceGroups = new List<string>(),
                ResourceTypeBreakdown = new Dictionary<string, int>(),
                ErrorMessages = new List<string>()
            };

            try
            {
                // Ensure ArmClient is initialized with a working credential
                _logger.LogInformation("Ensuring ARM client is authenticated and initialized...");
                try
                {
                    await EnsureArmClientInitializedAsync();
                    var subscriptions = _armClient!.GetSubscriptions();
                    var subscriptionCount = 0;
                    await foreach (var sub in subscriptions)
                    {
                        subscriptionCount++;
                        _logger.LogInformation($"Found subscription: {sub.Data.DisplayName} ({sub.Data.SubscriptionId})");
                        if (subscriptionCount >= 5) break; // Limit logging
                    }
                    _logger.LogInformation($"Authentication successful. Found {subscriptionCount}+ subscriptions.");
                }
                catch (Exception authEx)
                {
                    _logger.LogError(authEx, "Authentication failed");
                    result.ErrorMessages.Add($"Authentication failed: {authEx.Message}");
                    return result;
                }

                foreach (var subscriptionId in _targetSubscriptions)
                {
                    _logger.LogInformation($"Discovering resources in subscription: {subscriptionId}");
                    try
                    {
                        await DiscoverSubscriptionResourcesAsync(subscriptionId, result);
                    }
                    catch (Exception subEx)
                    {
                        _logger.LogError(subEx, $"Failed to discover resources in subscription {subscriptionId}");
                        result.ErrorMessages.Add($"Subscription {subscriptionId}: {subEx.Message}");
                    }
                }
                
                // Process discovered data to identify cells and patterns
                ProcessStampsPattern(result);
                
                _logger.LogInformation($"Discovery completed. Found {result.Resources.Count} resources across {result.Regions.Count} regions");
                if (result.ErrorMessages.Any())
                {
                    _logger.LogWarning($"Discovery completed with {result.ErrorMessages.Count} errors");
                }
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to discover Azure infrastructure");
                result.ErrorMessages.Add($"Discovery failed: {ex.Message}");
                return result;
            }
        }

        private async Task DiscoverSubscriptionResourcesAsync(string subscriptionId, AzureInfrastructureData result)
        {
            try
            {
                _logger.LogInformation($"Attempting to access subscription: {subscriptionId}");
                var subscription = _armClient.GetSubscriptionResource(new Azure.Core.ResourceIdentifier($"/subscriptions/{subscriptionId}"));
                
                // Test subscription access
                var subscriptionData = await subscription.GetAsync();
                _logger.LogInformation($"Successfully accessed subscription: {subscriptionData.Value.Data.DisplayName}");
                
                // Get all resource groups in the subscription
                var resourceGroupCount = 0;
                await foreach (var resourceGroup in subscription.GetResourceGroups())
                {
                    resourceGroupCount++;
                    var rgLocation = resourceGroup.Data.Location.Name;
                    
                    _logger.LogInformation($"Found resource group: {resourceGroup.Data.Name} in {rgLocation}");
                    
                    // Only process resources in our target regions
                    if (_targetRegions.Contains(rgLocation))
                    {
                        _logger.LogInformation($"Processing resource group: {resourceGroup.Data.Name} ({rgLocation}) - matches target region");
                        
                        if (!result.Regions.Contains(rgLocation))
                            result.Regions.Add(rgLocation);
                        
                        if (!result.ResourceGroups.Contains(resourceGroup.Data.Name))
                            result.ResourceGroups.Add(resourceGroup.Data.Name);
                        
                        await DiscoverResourceGroupResourcesAsync(resourceGroup, result);
                    }
                    else
                    {
                        _logger.LogDebug($"Skipping resource group: {resourceGroup.Data.Name} ({rgLocation}) - not in target regions");
                    }
                }
                _logger.LogInformation($"Processed {resourceGroupCount} resource groups in subscription {subscriptionId}");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to discover resources in subscription {subscriptionId}");
                result.ErrorMessages?.Add($"Subscription {subscriptionId}: {ex.Message}");
            }
        }

        private async Task DiscoverResourceGroupResourcesAsync(ResourceGroupResource resourceGroup, AzureInfrastructureData result)
        {
            try
            {
                // Discover different types of Azure resources
                await DiscoverWebAppsAsync(resourceGroup, result);
                await DiscoverVirtualMachinesAsync(resourceGroup, result);
                await DiscoverStorageAccountsAsync(resourceGroup, result);
                await DiscoverCosmosDBAccountsAsync(resourceGroup, result);
                await DiscoverSqlServersAsync(resourceGroup, result);
                await DiscoverContainerInstancesAsync(resourceGroup, result);
                
                // Discover generic resources to get the complete picture
                await DiscoverGenericResourcesAsync(resourceGroup, result);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to discover resources in resource group {resourceGroup.Data.Name}");
            }
        }

        private async Task DiscoverWebAppsAsync(ResourceGroupResource resourceGroup, AzureInfrastructureData result)
        {
            try
            {
                await foreach (var webApp in resourceGroup.GetWebSites())
                {
                    var resource = new DiscoveredResource
                    {
                        Id = webApp.Id,
                        Name = webApp.Data.Name,
                        Type = "Microsoft.Web/sites",
                        Region = webApp.Data.Location.Name,
                        Location = webApp.Data.Location.Name,
                        ResourceGroup = resourceGroup.Data.Name,
                        Status = "Running", // Default - could check actual status
                        Tags = webApp.Data.Tags.ToDictionary(t => t.Key, t => t.Value),
                        Properties = new Dictionary<string, object>
                        {
                            ["Kind"] = webApp.Data.Kind ?? "app",
                            ["DefaultHostName"] = webApp.Data.DefaultHostName,
                            ["State"] = webApp.Data.State?.ToString() ?? "Unknown"
                        }
                    };
                    
                    result.Resources.Add(resource);
                    UpdateResourceTypeCount(result, resource.Type);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to discover web apps in {resourceGroup.Data.Name}");
            }
        }

        private async Task DiscoverVirtualMachinesAsync(ResourceGroupResource resourceGroup, AzureInfrastructureData result)
        {
            try
            {
                await foreach (var vm in resourceGroup.GetVirtualMachines())
                {
                    var resource = new DiscoveredResource
                    {
                        Id = vm.Id,
                        Name = vm.Data.Name,
                        Type = "Microsoft.Compute/virtualMachines",
                        Region = vm.Data.Location.Name,
                        Location = vm.Data.Location.Name,
                        ResourceGroup = resourceGroup.Data.Name,
                        Status = vm.Data.VmId != null ? "Running" : "Unknown",
                        Tags = vm.Data.Tags.ToDictionary(t => t.Key, t => t.Value),
                        Properties = new Dictionary<string, object>
                        {
                            ["VmSize"] = vm.Data.HardwareProfile?.VmSize?.ToString() ?? "Unknown",
                            ["OsType"] = vm.Data.StorageProfile?.OSDisk?.OSType?.ToString() ?? "Unknown"
                        }
                    };
                    
                    result.Resources.Add(resource);
                    UpdateResourceTypeCount(result, resource.Type);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to discover virtual machines in {resourceGroup.Data.Name}");
            }
        }

        private async Task DiscoverStorageAccountsAsync(ResourceGroupResource resourceGroup, AzureInfrastructureData result)
        {
            try
            {
                await foreach (var storageAccount in resourceGroup.GetStorageAccounts())
                {
                    var resource = new DiscoveredResource
                    {
                        Id = storageAccount.Id,
                        Name = storageAccount.Data.Name,
                        Type = "Microsoft.Storage/storageAccounts",
                        Region = storageAccount.Data.Location.Name,
                        Location = storageAccount.Data.Location.Name,
                        ResourceGroup = resourceGroup.Data.Name,
                        Status = storageAccount.Data.StatusOfPrimary?.ToString() ?? "Unknown",
                        Tags = storageAccount.Data.Tags.ToDictionary(t => t.Key, t => t.Value),
                        Properties = new Dictionary<string, object>
                        {
                            ["Kind"] = storageAccount.Data.Kind?.ToString() ?? "Unknown",
                            ["SkuName"] = storageAccount.Data.Sku?.Name.ToString() ?? "Unknown",
                            ["AccessTier"] = storageAccount.Data.AccessTier?.ToString() ?? "Unknown"
                        }
                    };
                    
                    result.Resources.Add(resource);
                    UpdateResourceTypeCount(result, resource.Type);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to discover storage accounts in {resourceGroup.Data.Name}");
            }
        }

        private async Task DiscoverCosmosDBAccountsAsync(ResourceGroupResource resourceGroup, AzureInfrastructureData result)
        {
            try
            {
                await foreach (var cosmosAccount in resourceGroup.GetCosmosDBAccounts())
                {
                    var resource = new DiscoveredResource
                    {
                        Id = cosmosAccount.Id,
                        Name = cosmosAccount.Data.Name,
                        Type = "Microsoft.DocumentDB/databaseAccounts",
                        Region = cosmosAccount.Data.Location.Name,
                        Location = cosmosAccount.Data.Location.Name,
                        ResourceGroup = resourceGroup.Data.Name,
                        Status = "Available", // CosmosDB doesn't expose simple status
                        Tags = cosmosAccount.Data.Tags.ToDictionary(t => t.Key, t => t.Value),
                        Properties = new Dictionary<string, object>
                        {
                            ["Kind"] = cosmosAccount.Data.Kind?.ToString() ?? "GlobalDocumentDB",
                            ["ConsistencyLevel"] = cosmosAccount.Data.ConsistencyPolicy?.DefaultConsistencyLevel.ToString() ?? "Unknown"
                        }
                    };
                    
                    result.Resources.Add(resource);
                    UpdateResourceTypeCount(result, resource.Type);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to discover Cosmos DB accounts in {resourceGroup.Data.Name}");
            }
        }

        private async Task DiscoverSqlServersAsync(ResourceGroupResource resourceGroup, AzureInfrastructureData result)
        {
            try
            {
                await foreach (var sqlServer in resourceGroup.GetSqlServers())
                {
                    var resource = new DiscoveredResource
                    {
                        Id = sqlServer.Id,
                        Name = sqlServer.Data.Name,
                        Type = "Microsoft.Sql/servers",
                        Region = sqlServer.Data.Location.Name,
                        Location = sqlServer.Data.Location.Name,
                        ResourceGroup = resourceGroup.Data.Name,
                        Status = sqlServer.Data.State?.ToString() ?? "Ready",
                        Tags = sqlServer.Data.Tags.ToDictionary(t => t.Key, t => t.Value),
                        Properties = new Dictionary<string, object>
                        {
                            ["Version"] = sqlServer.Data.Version ?? "Unknown",
                            ["FullyQualifiedDomainName"] = sqlServer.Data.FullyQualifiedDomainName ?? "Unknown"
                        }
                    };
                    
                    result.Resources.Add(resource);
                    UpdateResourceTypeCount(result, resource.Type);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to discover SQL servers in {resourceGroup.Data.Name}");
            }
        }

        private async Task DiscoverContainerInstancesAsync(ResourceGroupResource resourceGroup, AzureInfrastructureData result)
        {
            try
            {
                await foreach (var containerGroup in resourceGroup.GetContainerGroups())
                {
                    var resource = new DiscoveredResource
                    {
                        Id = containerGroup.Id,
                        Name = containerGroup.Data.Name,
                        Type = "Microsoft.ContainerInstance/containerGroups",
                        Region = containerGroup.Data.Location.Name,
                        Location = containerGroup.Data.Location.Name,
                        ResourceGroup = resourceGroup.Data.Name,
                        Status = containerGroup.Data.ProvisioningState ?? "Unknown",
                        Tags = containerGroup.Data.Tags.ToDictionary(t => t.Key, t => t.Value),
                        Properties = new Dictionary<string, object>
                        {
                            ["OsType"] = containerGroup.Data.OSType.ToString() ?? "Unknown",
                            ["RestartPolicy"] = containerGroup.Data.RestartPolicy?.ToString() ?? "Always"
                        }
                    };
                    
                    result.Resources.Add(resource);
                    UpdateResourceTypeCount(result, resource.Type);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to discover container instances in {resourceGroup.Data.Name}");
            }
        }

        private async Task DiscoverGenericResourcesAsync(ResourceGroupResource resourceGroup, AzureInfrastructureData result)
        {
            try
            {
                foreach (var resource in resourceGroup.GetGenericResources())
                {
                    // Skip resources we've already discovered with specific methods
                    var resourceType = resource.Data.ResourceType.ToString();
                    if (IsAlreadyDiscovered(resourceType)) continue;
                    
                    var discoveredResource = new DiscoveredResource
                    {
                        Id = resource.Id,
                        Name = resource.Data.Name,
                        Type = resourceType,
                        Region = resource.Data.Location.Name,
                        Location = resource.Data.Location.Name,
                        ResourceGroup = resourceGroup.Data.Name,
                        Status = "Unknown",
                        Tags = resource.Data.Tags?.ToDictionary(t => t.Key, t => t.Value) ?? new Dictionary<string, string>(),
                        Properties = new Dictionary<string, object>()
                    };
                    
                    result.Resources.Add(discoveredResource);
                    UpdateResourceTypeCount(result, discoveredResource.Type);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to discover generic resources in {resourceGroup.Data.Name}");
            }
        }

        private bool IsAlreadyDiscovered(string resourceType)
        {
            var discoveredTypes = new[]
            {
                "Microsoft.Web/sites",
                "Microsoft.Compute/virtualMachines",
                "Microsoft.Storage/storageAccounts",
                "Microsoft.DocumentDB/databaseAccounts",
                "Microsoft.Sql/servers",
                "Microsoft.ContainerInstance/containerGroups"
            };
            
            return discoveredTypes.Contains(resourceType);
        }

        private void UpdateResourceTypeCount(AzureInfrastructureData result, string resourceType)
        {
            if (result.ResourceTypeBreakdown.ContainsKey(resourceType))
                result.ResourceTypeBreakdown[resourceType]++;
            else
                result.ResourceTypeBreakdown[resourceType] = 1;
        }

        private void ProcessStampsPattern(AzureInfrastructureData result)
        {
            // Identify cells based on resource grouping and naming patterns
            var cellGroups = result.Resources
                .Where(r => _targetRegions.Contains(r.Region))
                .GroupBy(r => new { r.Region, r.ResourceGroup })
                .ToList();

            foreach (var cellGroup in cellGroups)
            {
                var cell = new DiscoveredCell
                {
                    Name = $"{cellGroup.Key.Region}-{cellGroup.Key.ResourceGroup}",
                    Region = cellGroup.Key.Region,
                    ResourceGroup = cellGroup.Key.ResourceGroup,
                    ResourceCount = cellGroup.Count(),
                    IsHealthy = DetermineCellHealth(cellGroup.ToList()),
                    Resources = cellGroup.ToList()
                };
                
                result.Cells.Add(cell);
            }
        }

        private bool DetermineCellHealth(List<DiscoveredResource> resources)
        {
            // Simple health check - could be more sophisticated
            var healthyStatuses = new[] { "Running", "Ready", "Available", "Succeeded" };
            var healthyCount = resources.Count(r => healthyStatuses.Contains(r.Status));
            return healthyCount > resources.Count * 0.8; // 80% healthy threshold
        }
    }

    public class AzureInfrastructureData
    {
        public DateTime DiscoveredAt { get; set; }
        public List<DiscoveredCell> Cells { get; set; } = new();
        public List<DiscoveredResource> Resources { get; set; } = new();
        public List<string> Regions { get; set; } = new();
        public List<string> ResourceGroups { get; set; } = new();
        public Dictionary<string, int> ResourceTypeBreakdown { get; set; } = new();
        public List<string> ErrorMessages { get; set; } = new();
    }
}
