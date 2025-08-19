using Aspire.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

// Configuration for different deployment modes
var deploymentMode = builder.Configuration["DeploymentMode"] ?? "Development"; // Development, Staging, Production
var useLocalEmulator = builder.Configuration.GetValue<bool>("UseLocalEmulator", true);
var enableAzureServices = builder.Configuration.GetValue<bool>("EnableAzureServices", false);

// Azure configuration for production deployment
var azureSubscriptions = builder.Configuration.GetSection("Azure:TargetSubscriptions").Get<string[]>() ?? new[]
{
    "2fb123ca-e419-4838-9b44-c2eb71a21769",
    "480cb033-9a92-4912-9d30-c6b7bf795a87"
};

var azureRegions = builder.Configuration.GetSection("Azure:TargetRegions").Get<string[]>() ?? new[]
{
    "westus2",
    "westus3"
};

// Make containerized resources optional to avoid requiring DCP when running `dotnet run`.
var skipContainersEnv = Environment.GetEnvironmentVariable("ASPIRE_SKIP_CONTAINERS");
var skipContainers = string.IsNullOrWhiteSpace(skipContainersEnv) || bool.TryParse(skipContainersEnv, out var val) && val;

// Development mode: Local emulator and DAB
if (deploymentMode == "Development" && useLocalEmulator && !skipContainers)
{
    // Cosmos DB Emulator (for local dev)
    var cosmosEmu = builder.AddContainer("cosmos", "mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator", tag: "latest")
        .WithEnvironment("AZURE_COSMOS_EMULATOR_ENABLE_TELEMETRY", "false")
        .WithEnvironment("AZURE_COSMOS_EMULATOR_PARTITION_COUNT", "3")
        .WithEnvironment("AZURE_COSMOS_EMULATOR_ENABLE_DATA_PERSISTENCE", "true")
        .WithContainerRuntimeArgs("--cap-add=NET_ADMIN")
        .WithHttpEndpoint(port: 8085, targetPort: 8081, name: "cosmos");

    // Connection strings for development
    var cosmosConnForContainers = "AccountEndpoint=https://cosmos:8081/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==;";
    var cosmosConnForHost = "AccountEndpoint=https://localhost:8085/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==;";

    // DAB container for local development
    var dab = builder.AddContainer("dab", "mcr.microsoft.com/data-api-builder", tag: "latest")
        .WithBindMount("..\\dab\\dab-config.json", "/App/dab-config.json")
        .WithEnvironment("ASPNETCORE_URLS", "http://+:8082")
        .WithEnvironment("COSMOS_CONNECTION_STRING", Environment.GetEnvironmentVariable("COSMOS_CONNECTION_STRING") ?? cosmosConnForContainers)
        .WithHttpEndpoint(port: 8082, name: "http")
        .WithArgs(["dab", "start", "--host", "0.0.0.0", "--config", "/App/dab-config.json"]);
}

// Production/Staging mode: Azure services
IResourceBuilder<ParameterResource>? cosmosConnectionString = null;
IResourceBuilder<ParameterResource>? dabEndpointUrl = null;

if (deploymentMode == "Production" || deploymentMode == "Staging" || enableAzureServices)
{
    // Azure Cosmos DB connection string parameter
    cosmosConnectionString = builder.AddParameter("cosmos-connection-string", secret: true);
    
    // DAB endpoint parameter (could be Azure Container Apps, App Service, etc.)
    dabEndpointUrl = builder.AddParameter("dab-endpoint-url");
    
    // Azure Application Insights for production monitoring
    var appInsightsConnectionString = builder.AddParameter("appinsights-connection-string", secret: true);
}

// Portal application configuration
var portalBuilder = builder.AddProject("portal", "..\\src\\Portal\\Portal.csproj");

// Configure portal based on deployment mode
if (deploymentMode == "Development" && useLocalEmulator)
{
    portalBuilder
        .WithEnvironment("ASPNETCORE_URLS", "http://+:8081")
        .WithEnvironment("DAB_GRAPHQL_URL", "http://localhost:8082/graphql")
        .WithEnvironment("DeploymentMode", deploymentMode)
        .WithEnvironment("UseLocalEmulator", "true")
        .WithHttpEndpoint(port: 8081, name: "http");
}
else
{
    portalBuilder
        .WithEnvironment("ASPNETCORE_URLS", "https://+:8081")
        .WithEnvironment("DAB_GRAPHQL_URL", dabEndpointUrl)
        .WithEnvironment("COSMOS_CONNECTION_STRING", cosmosConnectionString)
        .WithEnvironment("DeploymentMode", deploymentMode)
        .WithEnvironment("EnableAzureServices", "true")
        .WithEnvironment("Azure__TargetSubscriptions__0", azureSubscriptions[0])
        .WithEnvironment("Azure__TargetSubscriptions__1", azureSubscriptions[1])
        .WithEnvironment("Azure__TargetRegions__0", azureRegions[0])
        .WithEnvironment("Azure__TargetRegions__1", azureRegions[1])
        .WithHttpsEndpoint(port: 8081, name: "https");
}

// Add Azure service discovery and health checks for production
if (deploymentMode == "Production" || enableAzureServices)
{
    portalBuilder
        .WithEnvironment("APPLICATIONINSIGHTS_CONNECTION_STRING", cosmosConnectionString) // Use the parameter
        .WithEnvironment("AZURE_CLIENT_ID", builder.AddParameter("azure-client-id"))
        .WithEnvironment("AZURE_TENANT_ID", builder.AddParameter("azure-tenant-id"))
        .WithEnvironment("AZURE_CLIENT_SECRET", builder.AddParameter("azure-client-secret", secret: true));
}

var app = builder.Build();

// Health check endpoints for orchestration
app.MapGet("/health", () => "Healthy");
app.MapGet("/ready", () => "Ready");

app.Run();
