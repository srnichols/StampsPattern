using Aspire.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

var portal = builder.AddProject("portal", "..\\src\\Portal\\Portal.csproj")
    .WithEnvironment("ASPNETCORE_URLS", "http://+:8081")
    .WithHttpEndpoint(port: 8081, name: "http");

builder.Build().Run();
