using Azure.Core;
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.CosmosDB;
using System.Text.Json;

namespace Portal.Services;

public class CosmosDiscoveryService
{
    private readonly ILogger<CosmosDiscoveryService> _logger;
    private readonly IConfiguration _configuration;
    private readonly ArmClient _armClient;

    // Target subscriptions and regions for Cosmos DB discovery
    private readonly List<string> _targetSubscriptions = new()
    {
        "2fb123ca-e419-4838-9b44-c2eb71a21769",
        "480cb033-9a92-4912-9d30-c6b7bf795a87"
    };

    private readonly List<string> _targetRegions = new()
    {
        "westus2",
        "westus3"
    };

    public CosmosDiscoveryService(ILogger<CosmosDiscoveryService> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
        
        var credential = new DefaultAzureCredential();
        _armClient = new ArmClient(credential);
    }

    public async Task<List<CosmosDbInstance>> DiscoverCosmosInstancesAsync()
    {
        var cosmosInstances = new List<CosmosDbInstance>();
        
        _logger.LogInformation("Starting Cosmos DB discovery for DAB configuration...");
        
        foreach (var subscriptionId in _targetSubscriptions)
        {
            try
            {
                var subscription = _armClient.GetSubscriptionResource(new ResourceIdentifier($"/subscriptions/{subscriptionId}"));
                
                await foreach (var resourceGroup in subscription.GetResourceGroups())
                {
                    var rgLocation = resourceGroup.Data.Location.Name;
                    
                    if (!_targetRegions.Contains(rgLocation))
                        continue;
                    
                    await foreach (var cosmosAccount in resourceGroup.GetCosmosDBAccounts())
                    {
                        var instance = await CreateCosmosInstanceAsync(cosmosAccount);
                        if (instance != null)
                        {
                            cosmosInstances.Add(instance);
                            _logger.LogInformation("Found Cosmos DB instance: {AccountName} in {ResourceGroup}", 
                                instance.AccountName, instance.ResourceGroup);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to discover Cosmos DB instances in subscription {SubscriptionId}", subscriptionId);
            }
        }
        
        _logger.LogInformation("Cosmos DB discovery complete. Found {Count} instances", cosmosInstances.Count);
        return cosmosInstances;
    }

    private async Task<CosmosDbInstance?> CreateCosmosInstanceAsync(CosmosDBAccountResource cosmosAccount)
    {
        try
        {
            var accountData = cosmosAccount.Data;
            
            // Get connection strings
            var connectionStrings = cosmosAccount.GetConnectionStrings();
            var connectionStringsList = new List<Azure.ResourceManager.CosmosDB.Models.CosmosDBAccountConnectionString>();
            foreach (var cs in connectionStrings)
            {
                connectionStringsList.Add(cs);
            }
            var primaryConnectionString = connectionStringsList
                .FirstOrDefault(cs => cs.Description == "Primary SQL Connection String");
            
            if (primaryConnectionString == null)
            {
                _logger.LogWarning("No primary connection string found for Cosmos account {AccountName}", accountData.Name);
                return null;
            }

            // Get databases
            var databases = new List<CosmosDatabaseInfo>();
            await foreach (var database in cosmosAccount.GetCosmosDBSqlDatabases())
            {
                var dbInfo = new CosmosDatabaseInfo
                {
                    Name = database.Data.Name,
                    ResourceId = database.Id
                };
                
                // Get containers for this database
                await foreach (var container in database.GetCosmosDBSqlContainers())
                {
                    dbInfo.Containers.Add(container.Data.Name);
                }
                
                databases.Add(dbInfo);
            }

            return new CosmosDbInstance
            {
                AccountName = accountData.Name,
                ResourceGroup = cosmosAccount.Id.ResourceGroupName!,
                Location = accountData.Location.Name,
                ResourceId = cosmosAccount.Id,
                ConnectionString = primaryConnectionString.ConnectionString,
                Databases = databases,
                IsStampsControlPlane = databases.Any(db => db.Name == "stamps-control-plane")
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create Cosmos instance for account {AccountId}", cosmosAccount.Id);
            return null;
        }
    }

    public async Task<string> GenerateDabConfigAsync(CosmosDbInstance cosmosInstance, string targetDatabase = "stamps-control-plane")
    {
        _logger.LogInformation("Generating DAB configuration for Cosmos instance {AccountName}", cosmosInstance.AccountName);
        
        var targetDb = cosmosInstance.Databases.FirstOrDefault(db => db.Name == targetDatabase);
        if (targetDb == null)
        {
            throw new InvalidOperationException($"Database '{targetDatabase}' not found in Cosmos instance {cosmosInstance.AccountName}");
        }

        var dabConfig = new
        {
            @schema = "https://dataapibuilder.azureedge.net/schemas/latest/dab.draft.schema.json",
            dataSource = new
            {
                databaseType = "cosmosdb_nosql",
                options = new
                {
                    database = targetDatabase,
                    schema = "schema.graphql"
                },
                connectionString = $"@env('COSMOS_CONNECTION_STRING_{cosmosInstance.AccountName.ToUpper()}')"
            },
            runtime = new
            {
                rest = new { enabled = true, path = "/api" },
                graphql = new { enabled = true, path = "/graphql" },
                authentication = new { provider = "StaticWebApps" }
            },
            entities = GenerateEntitiesConfig(targetDb)
        };

        return JsonSerializer.Serialize(dabConfig, new JsonSerializerOptions 
        { 
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.KebabCaseLower
        });
    }

    private object GenerateEntitiesConfig(CosmosDatabaseInfo database)
    {
        var entities = new Dictionary<string, object>();

        // Generate entity configurations based on discovered containers
        foreach (var container in database.Containers)
        {
            var entityName = container.ToPascalCase();
            var singularName = entityName.EndsWith("s") ? entityName.Substring(0, entityName.Length - 1) : entityName;
            
            entities[singularName] = new
            {
                source = container,
                graphql = new 
                { 
                    type = new 
                    { 
                        singular = singularName, 
                        plural = entityName 
                    } 
                },
                primaryKey = new[] { "id" },
                permissions = new[] 
                { 
                    new { role = "anonymous", actions = new[] { "read" } } 
                }
            };
        }

        return entities;
    }

    public async Task WriteConnectionStringToEnvironmentAsync(CosmosDbInstance cosmosInstance, string filePath)
    {
        var envVarName = $"COSMOS_CONNECTION_STRING_{cosmosInstance.AccountName.ToUpper()}";
        var envContent = $"{envVarName}={cosmosInstance.ConnectionString}";
        
        await File.AppendAllTextAsync(filePath, $"\n{envContent}");
        _logger.LogInformation("Added connection string environment variable {EnvVar} to {FilePath}", envVarName, filePath);
    }
}

public class CosmosDbInstance
{
    public string AccountName { get; set; } = string.Empty;
    public string ResourceGroup { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
    public ResourceIdentifier ResourceId { get; set; } = default!;
    public string ConnectionString { get; set; } = string.Empty;
    public List<CosmosDatabaseInfo> Databases { get; set; } = new();
    public bool IsStampsControlPlane { get; set; }
}

public class CosmosDatabaseInfo
{
    public string Name { get; set; } = string.Empty;
    public ResourceIdentifier ResourceId { get; set; } = default!;
    public List<string> Containers { get; set; } = new();
}

public static class StringExtensions
{
    public static string ToPascalCase(this string input)
    {
        if (string.IsNullOrEmpty(input))
            return input;
        
        return char.ToUpper(input[0]) + input.Substring(1);
    }
}
