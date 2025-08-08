using Aspire.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

// Data API Builder container (GraphQL) for local development
var dab = builder.AddContainer("dab", "mcr.microsoft.com/data-api-builder", tag: "latest")
    .WithBindMount("..\\dab\\dab-config.json", "/App/dab-config.json")
    .WithEnvironment("ASPNETCORE_URLS", "http://+:8082")
    // Provide COSMOS_CONNECTION_STRING via environment or user-secrets for DAB to connect to Cosmos
    .WithHttpEndpoint(port: 8082, name: "http")
    .WithArgs(["dab", "start", "--host", "0.0.0.0", "--config", "/App/dab-config.json"]);

var portal = builder.AddProject("portal", "..\\src\\Portal\\Portal.csproj")
    .WithEnvironment("ASPNETCORE_URLS", "http://+:8081")
    .WithEnvironment("DAB_GRAPHQL_URL", "http://localhost:8082/graphql")
    .WithHttpEndpoint(port: 8081, name: "http");

builder.Build().Run();
