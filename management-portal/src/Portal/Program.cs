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

// Add authentication and authorization only in Production
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
    }).AddDapr();

    builder.Services.AddRazorPages()
        .AddMicrosoftIdentityUI();
}
else
{
    // Development: No authentication/authorization
    builder.Services.AddRazorPages();
    builder.Services.AddControllers().AddDapr();
}

builder.Services.AddServerSideBlazor();

// Configure Application Insights
if (!string.IsNullOrWhiteSpace(builder.Configuration["ApplicationInsights:ConnectionString"]))
{
    builder.Services.AddApplicationInsightsTelemetry();
}

// Configure OpenTelemetry for distributed tracing (simplified)
if (!string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING")))
{
    // Basic Azure Monitor integration - will be enhanced later
    builder.Services.AddApplicationInsightsTelemetry();
}

// Configure HotChocolate GraphQL server
builder.Services.AddGraphQLServer()
    .AddQueryType<Stamps.ManagementPortal.GraphQL.Query>()
    .AddSubscriptionType<Stamps.ManagementPortal.GraphQL.Subscription>();

// Add HotChocolate in-memory subscription support
builder.Services.AddInMemorySubscriptions();

// Register TaskEventPublisher
builder.Services.AddSingleton<Stamps.ManagementPortal.Services.ITaskEventPublisher, Stamps.ManagementPortal.Services.TaskEventPublisher>();
// Use in-memory service for development
Console.WriteLine("Using InMemoryDataService for development");
builder.Services.AddScoped<Stamps.ManagementPortal.Services.IDataService, Stamps.ManagementPortal.Services.InMemoryDataService>();

// Configure Azure Infrastructure Service
builder.Services.AddScoped<Stamps.ManagementPortal.Services.IAzureInfrastructureService, Stamps.ManagementPortal.Services.AzureInfrastructureService>();

// Configure Cosmos Discovery Service for live data synchronization
builder.Services.AddScoped<Stamps.ManagementPortal.Services.ICosmosDiscoveryService, Stamps.ManagementPortal.Services.CosmosDiscoveryService>();

// Add health checks
builder.Services.AddHealthChecks();

var app = builder.Build();

// Map HotChocolate GraphQL endpoint
app.MapGraphQL("/graphql");

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

// Enable WebSockets for GraphQL subscriptions
app.UseWebSockets();

// Add authentication middleware for production only
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
