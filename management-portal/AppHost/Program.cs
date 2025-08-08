using Aspire.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

// Cosmos DB Emulator (for local dev). If you prefer local emulator app, set COSMOS_CONNECTION_STRING externally and skip this container.
var cosmosEmu = builder.AddContainer("cosmos", "mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator", tag: "latest")
    .WithEnvironment("AZURE_COSMOS_EMULATOR_ENABLE_TELEMETRY", "false")
    .WithEnvironment("AZURE_COSMOS_EMULATOR_PARTITION_COUNT", "3")
    .WithEnvironment("AZURE_COSMOS_EMULATOR_ENABLE_DATA_PERSISTENCE", "true")
    .WithContainerRuntimeArgs("--cap-add=NET_ADMIN")
    .WithHttpEndpoint(port: 8085, targetPort: 8081, name: "cosmos"); // maps emulator 8081 -> 8085 on host

// Connection strings:
// - Inside containers (same Docker/Aspire network): use the container hostname `cosmos` at port 8081.
// - From the host (for local tools like the Seeder): use https://localhost:8085 mapped above.
var cosmosConnForContainers = "AccountEndpoint=https://cosmos:8081/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==;";
var cosmosConnForHost = "AccountEndpoint=https://localhost:8085/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==;";

var dab = builder.AddContainer("dab", "mcr.microsoft.com/data-api-builder", tag: "latest")
    .WithBindMount("..\\dab\\dab-config.json", "/App/dab-config.json")
    .WithEnvironment("ASPNETCORE_URLS", "http://+:8082")
    // Prefer an explicit COSMOS_CONNECTION_STRING if provided by the user, otherwise default to the container-network connection.
    .WithEnvironment("COSMOS_CONNECTION_STRING", Environment.GetEnvironmentVariable("COSMOS_CONNECTION_STRING") ?? cosmosConnForContainers)
    // Provide COSMOS_CONNECTION_STRING via environment or user-secrets for DAB to connect to Cosmos
    .WithHttpEndpoint(port: 8082, name: "http")
    .WithArgs(["dab", "start", "--host", "0.0.0.0", "--config", "/App/dab-config.json"]);

// (Optional) Run Seeder manually: dotnet run --project management-portal/Seeder 

var portal = builder.AddProject("portal", "..\\src\\Portal\\Portal.csproj")
    .WithEnvironment("ASPNETCORE_URLS", "http://+:8081")
    .WithEnvironment("DAB_GRAPHQL_URL", "http://localhost:8082/graphql")
    .WithHttpEndpoint(port: 8081, name: "http");

builder.Build().Run();
