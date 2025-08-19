using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.Authorization;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.UI;

var builder = WebApplication.CreateBuilder(args);

// Configure forwarded headers for container apps
if (builder.Environment.IsProduction())
{
    builder.Services.Configure<ForwardedHeadersOptions>(options =>
    {
        options.ForwardedHeaders = Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.XForwardedFor | 
                                 Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.XForwardedProto;
        options.KnownNetworks.Clear();
        options.KnownProxies.Clear();
        options.ForwardedProtoHeaderName = "X-Forwarded-Proto";
    });
}

// Add authentication for production
if (builder.Environment.IsProduction())
{
    // Configure authentication to use HTTPS URLs
    builder.Services.Configure<OpenIdConnectOptions>(OpenIdConnectDefaults.AuthenticationScheme, options =>
    {
        options.Events = new OpenIdConnectEvents
        {
            OnRedirectToIdentityProvider = context =>
            {
                // Force HTTPS in redirect URIs
                context.Request.Scheme = "https";
                context.Request.Host = new HostString(context.Request.Host.Host, 443);
                return Task.CompletedTask;
            }
        };
    });
    
    builder.Services.AddAuthentication(OpenIdConnectDefaults.AuthenticationScheme)
        .AddMicrosoftIdentityWebApp(builder.Configuration.GetSection("AzureAd"));
    
    builder.Services.AddAuthorization(options =>
    {
        // Require authentication by default
        options.FallbackPolicy = options.DefaultPolicy;
        
        // Add role-based authorization
        options.AddPolicy("PlatformAdmin", policy =>
            policy.RequireRole("platform.admin"));
        
        options.AddPolicy("Authenticated", policy =>
            policy.RequireAuthenticatedUser());
    });
    
    builder.Services.AddControllersWithViews(options =>
    {
        var policy = new AuthorizationPolicyBuilder()
            .RequireAuthenticatedUser()
            .Build();
        options.Filters.Add(new AuthorizeFilter(policy));
    });
    
    builder.Services.AddRazorPages()
        .AddMicrosoftIdentityUI();
}
else
{
    builder.Services.AddRazorPages();
}

builder.Services.AddServerSideBlazor();

// Configure Application Insights
if (!string.IsNullOrWhiteSpace(builder.Configuration["ApplicationInsights:ConnectionString"]))
{
    builder.Services.AddApplicationInsightsTelemetry();
}

// Configure Dapr client and services
builder.Services.AddDapr(daprClientBuilder =>
{
    var daprHttpPort = Environment.GetEnvironmentVariable("DAPR_HTTP_PORT") ?? "3500";
    var daprGrpcPort = Environment.GetEnvironmentVariable("DAPR_GRPC_PORT") ?? "50001";
    daprClientBuilder.UseHttpEndpoint($"http://localhost:{daprHttpPort}")
                    .UseGrpcEndpoint($"http://localhost:{daprGrpcPort}");
});

// Configure OpenTelemetry for distributed tracing
builder.Services.AddOpenTelemetry()
    .WithTracing(tracingBuilder => tracingBuilder
        .AddAspNetCoreInstrumentation()
        .AddSource("Dapr.Client")
        .AddConsoleExporter() // For debugging
        .AddAzureMonitorTraceExporter()) // For Azure Monitor
    .WithMetrics(metricsBuilder => metricsBuilder
        .AddAspNetCoreInstrumentation()
        .AddMeter("Dapr.Client")
        .AddConsoleExporter() // For debugging
        .AddAzureMonitorMetricExporter()); // For Azure Monitor

// Configure GraphQL client
builder.Services.AddHttpClient("GraphQL", (sp, client) =>
{
    var cfg = sp.GetRequiredService<IConfiguration>();
    var baseUrl = cfg["DAB_GRAPHQL_URL"] ?? "";
    if (!string.IsNullOrWhiteSpace(baseUrl))
    {
        client.BaseAddress = new Uri(baseUrl);
    }
});

// Configure data service with Dapr capabilities
var useGraphQL = !string.IsNullOrWhiteSpace(builder.Configuration["DAB_GRAPHQL_URL"]);
var useDapr = !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("DAPR_HTTP_PORT"));

if (useGraphQL && useDapr)
{
    // Use Dapr-enabled data service for enhanced debugging and resilience
    builder.Services.AddScoped<Stamps.ManagementPortal.Services.GraphQLDataService>();
    builder.Services.AddScoped<Stamps.ManagementPortal.Services.IDataService, Stamps.ManagementPortal.Services.DaprDataService>();
}
else if (useGraphQL)
{
    // Use direct GraphQL service
    builder.Services.AddSingleton<Stamps.ManagementPortal.Services.IDataService, Stamps.ManagementPortal.Services.GraphQLDataService>();
}
else
{
    // Use in-memory service for development
    builder.Services.AddSingleton<Stamps.ManagementPortal.Services.IDataService, Stamps.ManagementPortal.Services.InMemoryDataService>();
}

// Configure Azure Infrastructure Service
builder.Services.AddScoped<Stamps.ManagementPortal.Services.IAzureInfrastructureService, Stamps.ManagementPortal.Services.AzureInfrastructureService>();

// Configure Cosmos Discovery Service for live data synchronization
builder.Services.AddScoped<Stamps.ManagementPortal.Services.ICosmosDiscoveryService, Stamps.ManagementPortal.Services.CosmosDiscoveryService>();

// Add health checks
builder.Services.AddHealthChecks();

var app = builder.Build();

// Configure the HTTP request pipeline
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

// Use forwarded headers for production
if (app.Environment.IsProduction())
{
    app.UseForwardedHeaders();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

// Add authentication middleware for production
if (app.Environment.IsProduction())
{
    app.UseAuthentication();
    app.UseAuthorization();
}

app.MapBlazorHub();
app.MapFallbackToPage("/_Host");

// Add authentication-related routes for production
if (app.Environment.IsProduction())
{
    app.MapControllers();
    app.MapRazorPages();
}

app.MapHealthChecks("/health");

app.Run();
