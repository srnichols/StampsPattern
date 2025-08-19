using Portal.Services;
using Stamps.ManagementPortal.Services;

namespace Portal.Services;

public class AspireOrchestrationService
{
    private readonly ILogger<AspireOrchestrationService> _logger;
    private readonly IConfiguration _configuration;
    private readonly AzureInfrastructureService _azureInfrastructureService;
    private readonly CosmosDiscoveryService _cosmosDiscoveryService;
    private readonly IHostEnvironment _environment;

    public AspireOrchestrationService(
        ILogger<AspireOrchestrationService> logger,
        IConfiguration configuration,
        AzureInfrastructureService azureInfrastructureService,
        CosmosDiscoveryService cosmosDiscoveryService,
        IHostEnvironment environment)
    {
        _logger = logger;
        _configuration = configuration;
        _azureInfrastructureService = azureInfrastructureService;
        _cosmosDiscoveryService = cosmosDiscoveryService;
        _environment = environment;
    }

    public async Task<AspireDeploymentPlan> GenerateDeploymentPlanAsync()
    {
        _logger.LogInformation("Generating Aspire deployment plan for environment: {Environment}", _environment.EnvironmentName);

        var plan = new AspireDeploymentPlan
        {
            Environment = _environment.EnvironmentName,
            DeploymentMode = _configuration["DeploymentMode"] ?? "Development",
            GeneratedAt = DateTime.UtcNow,
            UseLocalEmulator = _configuration.GetValue<bool>("UseLocalEmulator", true),
            EnableAzureServices = _configuration.GetValue<bool>("EnableAzureServices", false)
        };

        // Discover live Azure infrastructure
        if (plan.EnableAzureServices)
        {
            try
            {
                _logger.LogInformation("Discovering Azure infrastructure for deployment planning...");
                var infrastructureData = await _azureInfrastructureService.DiscoverInfrastructureAsync();
                var cosmosInstances = await _cosmosDiscoveryService.DiscoverCosmosInstancesAsync();

                plan.DiscoveredInfrastructure = new DeploymentInfrastructure
                {
                    ResourceGroups = infrastructureData.ResourceGroups,
                    Regions = infrastructureData.Regions,
                    ResourceTypeBreakdown = infrastructureData.ResourceTypeBreakdown,
                    CosmosInstances = cosmosInstances.Select(c => new DeploymentCosmosInstance
                    {
                        AccountName = c.AccountName,
                        ResourceGroup = c.ResourceGroup,
                        Location = c.Location,
                        HasStampsControlPlane = c.IsStampsControlPlane,
                        DatabaseCount = c.Databases.Count,
                        Databases = c.Databases.Select(db => db.Name).ToList()
                    }).ToList()
                };

                // Generate recommended service configurations
                plan.ServiceConfigurations = await GenerateServiceConfigurationsAsync(cosmosInstances);
                plan.HealthChecks = GenerateHealthCheckConfigurations();
                plan.MonitoringConfiguration = GenerateMonitoringConfiguration();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to discover Azure infrastructure for deployment plan");
                plan.Errors.Add($"Azure discovery failed: {ex.Message}");
            }
        }
        else
        {
            // Local development configuration
            plan.ServiceConfigurations = GenerateLocalServiceConfigurations();
        }

        return plan;
    }

    private async Task<List<ServiceConfiguration>> GenerateServiceConfigurationsAsync(List<CosmosDbInstance> cosmosInstances)
    {
        var configs = new List<ServiceConfiguration>();

        // Portal service configuration
        var portalConfig = new ServiceConfiguration
        {
            ServiceName = "portal",
            ServiceType = "AspNetCore",
            Replicas = _environment.IsProduction() ? 3 : 1,
            EnvironmentVariables = new Dictionary<string, string>
            {
                ["ASPNETCORE_ENVIRONMENT"] = _environment.EnvironmentName,
                ["EnableAzureServices"] = "true",
                ["Azure__TargetSubscriptions__0"] = "2fb123ca-e419-4838-9b44-c2eb71a21769",
                ["Azure__TargetSubscriptions__1"] = "480cb033-9a92-4912-9d30-c6b7bf795a87",
                ["Azure__TargetRegions__0"] = "westus2",
                ["Azure__TargetRegions__1"] = "westus3"
            },
            HealthCheckEndpoints = new List<string> { "/health", "/ready" },
            Dependencies = new List<string> { "dab" }
        };

        // Find the best Cosmos instance for stamps control plane
        var stampsCosmosInstance = cosmosInstances.FirstOrDefault(c => c.IsStampsControlPlane);
        if (stampsCosmosInstance != null)
        {
            portalConfig.EnvironmentVariables["PrimaryCosmosAccount"] = stampsCosmosInstance.AccountName;
            portalConfig.EnvironmentVariables["PrimaryCosmosResourceGroup"] = stampsCosmosInstance.ResourceGroup;
        }

        configs.Add(portalConfig);

        // DAB service configuration for each relevant Cosmos instance
        foreach (var cosmosInstance in cosmosInstances.Where(c => c.IsStampsControlPlane))
        {
            var dabConfig = new ServiceConfiguration
            {
                ServiceName = $"dab-{cosmosInstance.AccountName.ToLower()}",
                ServiceType = "DataApiBuilder",
                Replicas = _environment.IsProduction() ? 2 : 1,
                EnvironmentVariables = new Dictionary<string, string>
                {
                    ["COSMOS_CONNECTION_STRING"] = $"@secret(cosmos-{cosmosInstance.AccountName.ToLower()}-connection-string)",
                    ["ASPNETCORE_ENVIRONMENT"] = _environment.EnvironmentName
                },
                ConfigurationFiles = new List<string> { $"dab-config-{cosmosInstance.AccountName.ToLower()}.json" },
                Dependencies = new List<string>()
            };

            // Generate DAB config for this instance
            var dabConfigContent = await _cosmosDiscoveryService.GenerateDabConfigAsync(cosmosInstance);
            dabConfig.GeneratedConfigurations.Add($"dab-config-{cosmosInstance.AccountName.ToLower()}.json", dabConfigContent);

            configs.Add(dabConfig);
        }

        return configs;
    }

    private List<ServiceConfiguration> GenerateLocalServiceConfigurations()
    {
        return new List<ServiceConfiguration>
        {
            new ServiceConfiguration
            {
                ServiceName = "portal",
                ServiceType = "AspNetCore",
                Replicas = 1,
                EnvironmentVariables = new Dictionary<string, string>
                {
                    ["ASPNETCORE_ENVIRONMENT"] = "Development",
                    ["UseLocalEmulator"] = "true",
                    ["DAB_GRAPHQL_URL"] = "http://localhost:8082/graphql"
                },
                Dependencies = new List<string> { "cosmos-emulator", "dab" }
            },
            new ServiceConfiguration
            {
                ServiceName = "cosmos-emulator",
                ServiceType = "Container",
                Replicas = 1,
                ContainerImage = "mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:latest"
            },
            new ServiceConfiguration
            {
                ServiceName = "dab",
                ServiceType = "DataApiBuilder",
                Replicas = 1,
                Dependencies = new List<string> { "cosmos-emulator" }
            }
        };
    }

    private List<HealthCheckConfiguration> GenerateHealthCheckConfigurations()
    {
        return new List<HealthCheckConfiguration>
        {
            new HealthCheckConfiguration
            {
                Name = "portal-health",
                Type = "HTTP",
                Endpoint = "/health",
                IntervalSeconds = 30,
                TimeoutSeconds = 10
            },
            new HealthCheckConfiguration
            {
                Name = "dab-health",
                Type = "HTTP",
                Endpoint = "/health",
                IntervalSeconds = 30,
                TimeoutSeconds = 10
            },
            new HealthCheckConfiguration
            {
                Name = "azure-infrastructure-connectivity",
                Type = "Custom",
                CheckType = "AzureResourceAccess",
                IntervalSeconds = 60,
                TimeoutSeconds = 30
            }
        };
    }

    private MonitoringConfiguration GenerateMonitoringConfiguration()
    {
        return new MonitoringConfiguration
        {
            ApplicationInsights = new ApplicationInsightsConfig
            {
                EnabledForProduction = true,
                InstrumentationKey = "@secret(appinsights-instrumentation-key)",
                EnableDependencyTracking = true,
                EnablePerformanceCounters = true
            },
            OpenTelemetry = new OpenTelemetryConfig
            {
                EnableTracing = true,
                EnableMetrics = true,
                EnableLogging = true,
                ExportEndpoint = "https://stamps-otel-collector.azurecontainerapps.io"
            },
            CustomMetrics = new List<string>
            {
                "stamps.discovery.execution_time",
                "stamps.infrastructure.resource_count",
                "stamps.cells.health_status",
                "stamps.dab.query_performance"
            }
        };
    }

    public async Task<string> GenerateAspireManifestAsync(AspireDeploymentPlan plan)
    {
        _logger.LogInformation("Generating Aspire deployment manifest for {Environment}", plan.Environment);

        var manifest = new
        {
            aspire = new
            {
                version = "1.0.0",
                environment = plan.Environment,
                deploymentMode = plan.DeploymentMode,
                generatedAt = plan.GeneratedAt.ToString("O")
            },
            services = plan.ServiceConfigurations.ToDictionary(
                sc => sc.ServiceName,
                sc => new
                {
                    type = sc.ServiceType,
                    replicas = sc.Replicas,
                    environment = sc.EnvironmentVariables,
                    dependencies = sc.Dependencies,
                    healthChecks = sc.HealthCheckEndpoints
                }
            ),
            infrastructure = plan.DiscoveredInfrastructure != null ? new
            {
                resourceGroups = plan.DiscoveredInfrastructure.ResourceGroups,
                regions = plan.DiscoveredInfrastructure.Regions,
                cosmosInstances = plan.DiscoveredInfrastructure.CosmosInstances?.Select(c => new
                {
                    accountName = c.AccountName,
                    resourceGroup = c.ResourceGroup,
                    location = c.Location,
                    hasStampsControlPlane = c.HasStampsControlPlane
                })
            } : null,
            healthChecks = plan.HealthChecks.ToDictionary(
                hc => hc.Name,
                hc => new
                {
                    type = hc.Type,
                    endpoint = hc.Endpoint,
                    intervalSeconds = hc.IntervalSeconds
                }
            ),
            monitoring = new
            {
                applicationInsights = plan.MonitoringConfiguration.ApplicationInsights,
                openTelemetry = plan.MonitoringConfiguration.OpenTelemetry,
                customMetrics = plan.MonitoringConfiguration.CustomMetrics
            }
        };

        return System.Text.Json.JsonSerializer.Serialize(manifest, new System.Text.Json.JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase
        });
    }
}

public class AspireDeploymentPlan
{
    public string Environment { get; set; } = string.Empty;
    public string DeploymentMode { get; set; } = string.Empty;
    public DateTime GeneratedAt { get; set; }
    public bool UseLocalEmulator { get; set; }
    public bool EnableAzureServices { get; set; }
    public DeploymentInfrastructure? DiscoveredInfrastructure { get; set; }
    public List<ServiceConfiguration> ServiceConfigurations { get; set; } = new();
    public List<HealthCheckConfiguration> HealthChecks { get; set; } = new();
    public MonitoringConfiguration MonitoringConfiguration { get; set; } = new();
    public List<string> Errors { get; set; } = new();
}

public class DeploymentInfrastructure
{
    public List<string> ResourceGroups { get; set; } = new();
    public List<string> Regions { get; set; } = new();
    public Dictionary<string, int> ResourceTypeBreakdown { get; set; } = new();
    public List<DeploymentCosmosInstance> CosmosInstances { get; set; } = new();
}

public class DeploymentCosmosInstance
{
    public string AccountName { get; set; } = string.Empty;
    public string ResourceGroup { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
    public bool HasStampsControlPlane { get; set; }
    public int DatabaseCount { get; set; }
    public List<string> Databases { get; set; } = new();
}

public class ServiceConfiguration
{
    public string ServiceName { get; set; } = string.Empty;
    public string ServiceType { get; set; } = string.Empty;
    public int Replicas { get; set; }
    public Dictionary<string, string> EnvironmentVariables { get; set; } = new();
    public List<string> Dependencies { get; set; } = new();
    public List<string> HealthCheckEndpoints { get; set; } = new();
    public List<string> ConfigurationFiles { get; set; } = new();
    public Dictionary<string, string> GeneratedConfigurations { get; set; } = new();
    public string? ContainerImage { get; set; }
}

public class HealthCheckConfiguration
{
    public string Name { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public string? Endpoint { get; set; }
    public string? CheckType { get; set; }
    public int IntervalSeconds { get; set; } = 30;
    public int TimeoutSeconds { get; set; } = 10;
}

public class MonitoringConfiguration
{
    public ApplicationInsightsConfig ApplicationInsights { get; set; } = new();
    public OpenTelemetryConfig OpenTelemetry { get; set; } = new();
    public List<string> CustomMetrics { get; set; } = new();
}

public class ApplicationInsightsConfig
{
    public bool EnabledForProduction { get; set; }
    public string? InstrumentationKey { get; set; }
    public bool EnableDependencyTracking { get; set; }
    public bool EnablePerformanceCounters { get; set; }
}

public class OpenTelemetryConfig
{
    public bool EnableTracing { get; set; }
    public bool EnableMetrics { get; set; }
    public bool EnableLogging { get; set; }
    public string? ExportEndpoint { get; set; }
}
