using Aspire.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

var portal = builder.AddProject("portal", "..\\src\\Portal\\Portal.csproj")
    .WithEnvironment("ASPNETCORE_URLS", "http://+:8080")
    .WithHttpEndpoint(port: 8080, name: "http");

builder.Build().Run();
