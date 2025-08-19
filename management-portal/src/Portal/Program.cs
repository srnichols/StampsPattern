using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.Authorization;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.UI;
using Portal.Services;
using Stamps.ManagementPortal.Services;
using Stamps.ManagementPortal.Models;

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

// Configure authentication conditionally - disable in production for testing
if (builder.Environment.IsDevelopment())
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
    // Production: No authentication for testing Azure discovery features
    builder.Services.AddAuthorization();
    builder.Services.AddRazorPages();
}

builder.Services.AddServerSideBlazor();

// Register HttpClient so server-side components can call our minimal API
builder.Services.AddHttpClient();

// Configure Application Insights
if (!string.IsNullOrWhiteSpace(builder.Configuration["ApplicationInsights:ConnectionString"]))
{
    builder.Services.AddApplicationInsightsTelemetry();
}

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

// Configure data service
var useGraphQL = !string.IsNullOrWhiteSpace(builder.Configuration["DAB_GRAPHQL_URL"]);
if (useGraphQL)
{
    builder.Services.AddSingleton<Stamps.ManagementPortal.Services.IDataService, Stamps.ManagementPortal.Services.GraphQLDataService>();
}
else
{
    builder.Services.AddSingleton<Stamps.ManagementPortal.Services.IDataService, Stamps.ManagementPortal.Services.InMemoryDataService>();
}

// Add Azure Infrastructure Service for real resource discovery
// Add custom services
builder.Services.AddScoped<AzureInfrastructureService>();
builder.Services.AddScoped<CosmosDiscoveryService>();
builder.Services.AddScoped<AspireOrchestrationService>();

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

// Add authentication middleware only in development
if (app.Environment.IsDevelopment())
{
    app.UseAuthentication();
    app.UseAuthorization();
}

app.MapBlazorHub();
app.MapFallbackToPage("/_Host");

// Add authentication-related routes only in development
if (app.Environment.IsDevelopment())
{
    app.MapControllers();
    app.MapRazorPages();
}

app.MapHealthChecks("/health");

// Minimal API endpoint to return discovery JSON so we can inspect results remotely.
// Public read-only endpoint that invokes the same server-side discovery used by the UI.
// Minimal discovery endpoint with optional API key protection.
var discoveryApiKey = builder.Configuration["DISCOVERY_API_KEY"] ?? Environment.GetEnvironmentVariable("DISCOVERY_API_KEY");

// Helper to authorize discovery requests when running in Production and when a key is configured
bool IsAuthorized(HttpContext http)
{
    if (app.Environment.IsDevelopment()) return true; // allow local/dev for testing
    if (string.IsNullOrWhiteSpace(discoveryApiKey)) return false; // deny if no key configured in prod
    return http.Request.Headers.TryGetValue("x-api-key", out var v) && v == discoveryApiKey;
}

// Discovery endpoint with optional filtering and pagination
app.MapGet("/api/discovery", async (Stamps.ManagementPortal.Services.AzureInfrastructureService svc, HttpContext http, string? region, string? resourceType, int? page, int? pageSize) =>
{
    if (!IsAuthorized(http)) return Results.Unauthorized();

    var data = await svc.DiscoverInfrastructureAsync();

    // Apply filters
    IEnumerable<object> resources = data.Resources;
    if (!string.IsNullOrWhiteSpace(region)) resources = data.Resources.Where(r => string.Equals(r.Region, region, StringComparison.OrdinalIgnoreCase));
    if (!string.IsNullOrWhiteSpace(resourceType)) resources = ((IEnumerable<DiscoveredResource>)resources).Where(r => string.Equals(r.Type, resourceType, StringComparison.OrdinalIgnoreCase));

    // Pagination
    var pg = page.GetValueOrDefault(1);
    var ps = pageSize.GetValueOrDefault(200);
    var total = resources.Count();
    var paged = resources.Skip((pg - 1) * ps).Take(ps).ToList();

    var resp = new {
        DiscoveredAt = data.DiscoveredAt,
        Regions = data.Regions,
        ResourceGroups = data.ResourceGroups,
        ResourceTypeBreakdown = data.ResourceTypeBreakdown,
        TotalResources = total,
        Page = pg,
        PageSize = ps,
        Resources = paged
    };

    return Results.Json(resp);
});

// CSV download endpoint
app.MapGet("/api/discovery/csv", async (Stamps.ManagementPortal.Services.AzureInfrastructureService svc, HttpContext http) =>
{
    if (!IsAuthorized(http)) return Results.Unauthorized();

    var data = await svc.DiscoverInfrastructureAsync();

    var sb = new System.Text.StringBuilder();
    sb.AppendLine("Id,Name,Type,Region,ResourceGroup,Status");
    foreach (var r in data.Resources)
    {
        var line = string.Format("\"{0}\",\"{1}\",\"{2}\",\"{3}\",\"{4}\",\"{5}\"",
            (r.Id ?? string.Empty).Replace("\"", "''"),
            (r.Name ?? string.Empty).Replace("\"", "''"),
            r.Type ?? string.Empty,
            r.Region ?? string.Empty,
            r.ResourceGroup ?? string.Empty,
            r.Status ?? string.Empty);
        sb.AppendLine(line);
    }

    var bytes = System.Text.Encoding.UTF8.GetBytes(sb.ToString());
    return Results.File(bytes, "text/csv", "discovery.csv");
});

// Server-side proxy for UI to download CSV without embedding the API key in the browser.
// WARNING: This endpoint intentionally bypasses the DISCOVERY_API_KEY header check to allow same-origin UI downloads.
// Recommend adding proper auth or a server-side session check before enabling in production.
app.MapGet("/api/discovery/download", async (Stamps.ManagementPortal.Services.AzureInfrastructureService svc) =>
{
    var data = await svc.DiscoverInfrastructureAsync();

    var sb = new System.Text.StringBuilder();
    sb.AppendLine("Id,Name,Type,Region,ResourceGroup,Status");
    foreach (var r in data.Resources)
    {
        var line = string.Format("\"{0}\",\"{1}\",\"{2}\",\"{3}\",\"{4}\",\"{5}\"",
            (r.Id ?? string.Empty).Replace("\"", "''"),
            (r.Name ?? string.Empty).Replace("\"", "''"),
            r.Type ?? string.Empty,
            r.Region ?? string.Empty,
            r.ResourceGroup ?? string.Empty,
            r.Status ?? string.Empty);
        sb.AppendLine(line);
    }

    var bytes = System.Text.Encoding.UTF8.GetBytes(sb.ToString());
    return Results.File(bytes, "text/csv", "discovery.csv");
});

// Quick audit endpoint that summarizes important resource types
app.MapGet("/api/audit", async (Stamps.ManagementPortal.Services.AzureInfrastructureService svc, HttpContext http) =>
{
    if (!IsAuthorized(http)) return Results.Unauthorized();

    var data = await svc.DiscoverInfrastructureAsync();
    var cosmos = data.Resources.Where(r => r.Type == "Microsoft.DocumentDB/databaseAccounts").Select(r => new { r.Name, r.ResourceGroup, r.Region }).ToList();
    var containerApps = data.Resources.Where(r => r.Type == "Microsoft.App/containerApps" || r.Type == "Microsoft.ContainerInstance/containerGroups").Select(r => new { r.Name, r.ResourceGroup, r.Region }).ToList();
    var keyvaults = data.Resources.Where(r => r.Type == "Microsoft.KeyVault/vaults").Select(r => new { r.Name, r.ResourceGroup, r.Region }).ToList();

    var summary = new {
        DiscoveredAt = data.DiscoveredAt,
        CosmosAccounts = cosmos,
        ContainerApps = containerApps,
        KeyVaults = keyvaults,
        ResourceCounts = data.ResourceTypeBreakdown
    };

    return Results.Json(summary);
});

app.Run();
