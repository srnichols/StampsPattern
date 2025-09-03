
using Microsoft.Extensions.DependencyInjection;
using HealthChecks.CosmosDb;
using Microsoft.Extensions.Caching.StackExchangeRedis;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Components.Authorization;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.Azure.Cosmos;
using Azure.Storage.Blobs;
using StackExchange.Redis;
using System.Text;
using System.Diagnostics.CodeAnalysis;
using TaskTracker.Blazor.Services;
using HotChocolate.AspNetCore;
using HotChocolate.AspNetCore.Authorization;
using Dapr.Client;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Logs;
using Microsoft.AspNetCore.RateLimiting;
using System.Threading.RateLimiting;
using TaskTracker.Blazor.Services.Options;
using Microsoft.Extensions.Options;

public partial class Program
{
    public static async Task Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // OpenTelemetry: logs sent through the logging builder
        builder.Logging.ClearProviders();
        builder.Logging.AddConsole();
    builder.Logging.AddOpenTelemetry(logging =>
        {
            logging.IncludeFormattedMessage = true;
            logging.IncludeScopes = true;
            logging.ParseStateValues = true;
            logging.AddOtlpExporter();
        });
    // Standardized API errors
    builder.Services.AddProblemDetails();

        // Add services to the container
        builder.Services.AddRazorPages();
        builder.Services.AddServerSideBlazor();
        builder.Services.AddResponseCompression(opts =>
        {
            opts.EnableForHttps = true;
            // defaults + binaries used by Blazor
            opts.MimeTypes = System.Linq.Enumerable.Concat(
                Microsoft.AspNetCore.ResponseCompression.ResponseCompressionDefaults.MimeTypes,
                new[] { "application/octet-stream" });
        });
        
        // Add controller support for Dapr endpoints
        builder.Services.AddControllers();

        // Bind options with validation
        builder.Services
            .AddOptions<CosmosOptions>()
            .PostConfigure(o =>
            {
                o.ConnectionString = builder.Configuration.GetConnectionString("CosmosDb");
                o.DatabaseName = builder.Configuration["CosmosDb:DatabaseName"] ?? o.DatabaseName;
            })
            .Validate(o => !string.IsNullOrWhiteSpace(o.DatabaseName), "CosmosDb:DatabaseName is required")
            .ValidateOnStart();

        builder.Services
            .AddOptions<BlobOptions>()
            .PostConfigure(o =>
            {
                o.ConnectionString = builder.Configuration.GetConnectionString("BlobStorage");
                o.ContainerName = builder.Configuration["BlobStorage:ContainerName"] ?? o.ContainerName;
            })
            .Validate(o => !string.IsNullOrWhiteSpace(o.ContainerName), "BlobStorage:ContainerName is required")
            .ValidateOnStart();

        builder.Services
            .AddOptions<RedisOptions>()
            .PostConfigure(o =>
            {
                o.ConnectionString = builder.Configuration.GetConnectionString("Redis");
            });

        // Authentication
        builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidateLifetime = true,
                    ValidateIssuerSigningKey = true,
                    ValidIssuer = builder.Configuration["Jwt:Issuer"] ?? "TaskTracker",
                    ValidAudience = builder.Configuration["Jwt:Audience"] ?? "TaskTracker",
                    IssuerSigningKey = new SymmetricSecurityKey(
                        Encoding.UTF8.GetBytes(builder.Configuration["Jwt:SecretKey"] ?? "your-secret-key-here-make-it-long-enough-for-security"))
                };
            });

        builder.Services.AddAuthorization();

        // Custom Authentication State Provider
        builder.Services.AddScoped<AuthenticationStateProvider, CustomAuthenticationStateProvider>();
        builder.Services.AddScoped<IAuthenticationService, AuthenticationService>();

    // Dapr Client (for pub/sub or state)
    builder.Services.AddSingleton(sp => new DaprClientBuilder().Build());
    
    // Dapr-based services
    builder.Services.AddScoped<IDaprStateService, DaprStateService>();

        // Azure Services
        builder.Services.AddSingleton(sp =>
        {
            var cosmosOpts = sp.GetRequiredService<IOptions<CosmosOptions>>().Value;
            var cosmosConnectionString = cosmosOpts.ConnectionString;
            if (string.IsNullOrEmpty(cosmosConnectionString))
            {
                // For development, use emulator in Docker compose service name
                cosmosConnectionString = "AccountEndpoint=https://cosmosdb:8081/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==";
            }

            var cosmosClientOptions = new CosmosClientOptions
            {
                ConnectionMode = ConnectionMode.Gateway,
                // Ensure we only use the provided endpoint (emulator) and don't resolve region-specific hosts
                LimitToEndpoint = true,
                SerializerOptions = new CosmosSerializationOptions
                {
                    PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase
                },
                HttpClientFactory = () =>
                {
                    var handler = new HttpClientHandler
                    {
                        ServerCertificateCustomValidationCallback = HttpClientHandler.DangerousAcceptAnyServerCertificateValidator
                    };
                    var client = new HttpClient(handler)
                    {
                        // Emulator can be slow to respond on first calls
                        Timeout = TimeSpan.FromSeconds(15)
                    };
                    return client;
                }
            };
            return new CosmosClient(cosmosConnectionString, cosmosClientOptions);
        });

        builder.Services.AddSingleton(sp =>
        {
            var blobOpts = sp.GetRequiredService<IOptions<BlobOptions>>().Value;
            var blobConnectionString = blobOpts.ConnectionString;
            if (string.IsNullOrEmpty(blobConnectionString))
            {
                // For development, use Azurite emulator
                blobConnectionString = "UseDevelopmentStorage=true";
            }
            return new BlobServiceClient(blobConnectionString);
        });

    // Redis for caching (optional - can be disabled for development)
    if (!string.IsNullOrEmpty(builder.Configuration.GetConnectionString("Redis")))
        {
            builder.Services.AddStackExchangeRedisCache(options =>
            {
                options.Configuration = builder.Configuration.GetConnectionString("Redis");
            });
        }
        else
        {
            // Use in-memory cache for development
            builder.Services.AddMemoryCache();
        }

        // Always use direct CosmosDbService for DAL; GraphQL endpoint will use it as backend
        builder.Services.AddScoped<ICosmosDbService, CosmosDbService>();

        // Register HotChocolate GraphQL server with subscriptions
        builder.Services
            .AddGraphQLServer()
            .AddAuthorization()
            .AddQueryType<TaskTracker.Blazor.GraphQL.Query>()
            .AddMutationType<TaskTracker.Blazor.GraphQL.Mutation>()
            .AddSubscriptionType<TaskTracker.Blazor.GraphQL.Subscription>()
            .AddInMemorySubscriptions();

    builder.Services.AddScoped<IBlobStorageService, BlobStorageService>();
        builder.Services.AddSingleton<IIconService, IconService>();
    builder.Services.AddSingleton<ThemeState>();
    builder.Services.AddSingleton<ISeederService, SeederService>();

        // CORS for development
        builder.Services.AddCors(options =>
        {
            options.AddPolicy("AllowAll", policy =>
            {
                policy.AllowAnyOrigin()
                      .AllowAnyMethod()
                      .AllowAnyHeader();
            });
        });

        // Lightweight rate limiting policy for select public endpoints
        builder.Services.AddRateLimiter(options =>
        {
            options.AddFixedWindowLimiter("public", limiterOptions =>
            {
                limiterOptions.PermitLimit = 60;
                limiterOptions.Window = TimeSpan.FromMinutes(1);
                limiterOptions.QueueLimit = 0;
                limiterOptions.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
            });
        });

        // Health checks
        builder.Services.AddHealthChecks()
            .AddCheck<TaskTracker.Blazor.Services.Health.CosmosHealthCheck>("cosmos", tags: new[] { "ready" })
            .AddCheck<TaskTracker.Blazor.Services.Health.BlobStorageHealthCheck>("blob", tags: new[] { "ready" })
            .AddCheck<TaskTracker.Blazor.Services.Health.RedisHealthCheck>("redis", failureStatus: Microsoft.Extensions.Diagnostics.HealthChecks.HealthStatus.Degraded, tags: new[] { "ready" });

        // OpenTelemetry: Traces and Metrics
        var serviceName = builder.Configuration["OTEL_SERVICE_NAME"] ?? "TaskTracker.Blazor";
        var resourceBuilder = ResourceBuilder.CreateDefault()
            .AddService(serviceName: serviceName, serviceVersion: typeof(Program).Assembly.GetName().Version?.ToString() ?? "1.0.0")
            .AddAttributes(new[]
            {
                new KeyValuePair<string, object>("deployment.environment", builder.Environment.EnvironmentName),
            });

        builder.Services.AddOpenTelemetry()
            .ConfigureResource(rb => rb.AddService(serviceName))
            .WithTracing(tracing => tracing
                .SetResourceBuilder(resourceBuilder)
                .AddAspNetCoreInstrumentation(options =>
                {
                    options.RecordException = true;
                    options.Filter = httpContext => !httpContext.Request.Path.StartsWithSegments("/health")
                        && !httpContext.Request.Path.StartsWithSegments("/healthz")
                        && !httpContext.Request.Path.StartsWithSegments("/readyz");
                })
                .AddHttpClientInstrumentation(options =>
                {
                    options.RecordException = true;
                    options.EnrichWithHttpResponseMessage = (activity, response) =>
                    {
                        activity.SetTag("http.response_content_length", response.Content?.Headers.ContentLength);
                    };
                })
                .AddOtlpExporter())
            .WithMetrics(metrics => metrics
                .SetResourceBuilder(resourceBuilder)
                .AddRuntimeInstrumentation()
                .AddAspNetCoreInstrumentation()
                .AddOtlpExporter());

        var app = builder.Build();

        // Configure the HTTP request pipeline
    if (!app.Environment.IsDevelopment())
        {
            app.UseExceptionHandler("/Error");
            app.UseHsts();
        }

        // Only redirect to HTTPS if URLs include https
        if ((builder.Configuration["ASPNETCORE_URLS"] ?? string.Empty).Contains("https"))
        {
            app.UseHttpsRedirection();
        }
    app.UseResponseCompression();
    app.UseStaticFiles();

        app.UseRouting();

    app.UseCors("AllowAll");
    app.UseRateLimiter();
        app.UseAuthentication();
        app.UseAuthorization();

        // Enrich spans/logs with tenant, user and correlation details and create a logging scope
        app.Use(async (context, next) =>
        {
            try
            {
                var authSvc = context.RequestServices.GetService<IAuthenticationService>();
                var tenantId = authSvc?.GetCurrentTenantId();
                var userId = authSvc?.GetCurrentUserId();
                if (!string.IsNullOrWhiteSpace(tenantId))
                {
                    System.Diagnostics.Activity.Current?.SetTag("tenant.id", tenantId);
                }

                var corrId = context.Request.Headers["x-correlation-id"].FirstOrDefault();
                if (string.IsNullOrEmpty(corrId))
                {
                    corrId = Guid.NewGuid().ToString("n");
                    context.Response.Headers["x-correlation-id"] = corrId;
                }
                System.Diagnostics.Activity.Current?.SetTag("correlation.id", corrId);

                var loggerFactory = context.RequestServices.GetService<ILoggerFactory>();
                using var scope = loggerFactory?.CreateLogger("RequestScope")
                    .BeginScope(new Dictionary<string, object?>
                    {
                        ["tenant.id"] = tenantId,
                        ["user.id"] = userId,
                        ["correlation.id"] = corrId
                    });
                await next();
                return;
            }
            catch { /* best-effort enrichment */ }

            await next();
        });

        // Map controllers for Dapr endpoints
        app.MapControllers();

        // Liveness: simple self-check
        app.MapGet("/health", () => Results.Ok(new { status = "OK" }));
        // Readiness: checks external dependencies
        app.MapHealthChecks("/readyz", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
        {
            Predicate = reg => reg.Tags.Contains("ready"),
        });
        // Aggregate health: all checks
        app.MapHealthChecks("/healthz");

        // Map HotChocolate GraphQL endpoint
        app.MapGraphQL("/graphql");

        // API endpoints for SAS token generation
    app.MapPost("/api/upload/sas", async (
            HttpContext http,
            [FromBody] SASRequest request,
            IBlobStorageService blobService,
            IAuthenticationService authService) =>
        {
            var corrId = http.Request.Headers["x-correlation-id"].FirstOrDefault() ?? http.Response.Headers["x-correlation-id"].FirstOrDefault();
            var tenantId = authService.GetCurrentTenantId();
            if (string.IsNullOrEmpty(tenantId))
                return Results.Unauthorized();

            if (request.TaskId == Guid.Empty || string.IsNullOrWhiteSpace(request.FileName))
            {
                var errors = new Dictionary<string, string[]>
                {
                    [nameof(request.TaskId)] = request.TaskId == Guid.Empty ? new[] { "TaskId is required." } : Array.Empty<string>(),
                    [nameof(request.FileName)] = string.IsNullOrWhiteSpace(request.FileName) ? new[] { "FileName is required." } : Array.Empty<string>()
                }.Where(kv => kv.Value.Length > 0).ToDictionary(kv => kv.Key, kv => kv.Value);
                return Results.ValidationProblem(errors);
            }

            try
            {
                var sasUrl = await blobService.GenerateUploadSasAsync(tenantId, request.TaskId, request.FileName);
                return Results.Ok(new { uploadUrl = sasUrl });
            }
            catch (Exception ex)
            {
                return Results.Problem(
                    title: "Failed to generate upload SAS",
                    detail: ex.Message,
                    statusCode: StatusCodes.Status500InternalServerError,
                    extensions: new Dictionary<string, object?>
                    {
                        ["correlationId"] = corrId,
                        ["tenantId"] = tenantId
                    });
            }
    })
    .RequireRateLimiting("public");

    // Dev-only: simple seed status + JSON seeding endpoints
    if (app.Environment.IsDevelopment())
        {
            // Dev-only: JSON fixtures seeding (files under /app/seed or Seed:JsonPath)
            app.MapPost("/dev/seed-json", async (HttpContext http, IConfiguration cfg, ISeederService seeder, CosmosClient client) =>
            {
                var dbName = cfg["CosmosDb:DatabaseName"] ?? "TaskTrackerDb";
                var path = cfg["Seed:JsonPath"];
                if (string.IsNullOrWhiteSpace(path)) path = "/app/seed";
                if (!Directory.Exists(path)) return Results.NotFound(new { message = "Seed directory not found", path });
                var report = await seeder.SeedFromJsonFilesAsync(path, dbName);
                return Results.Json(report, new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
            });

    app.MapGet("/dev/seed-status", async (HttpContext http, IConfiguration cfg, CosmosClient client) =>
            {
                var dbName = cfg["CosmosDb:DatabaseName"] ?? "TaskTrackerDb";
        var wantsHtml = (TryGetFormat(http.Request, out var fmt) && string.Equals(fmt, "html", StringComparison.OrdinalIgnoreCase))
                || Accepts(http.Request, "text/html");
        var wantsJson = (TryGetFormat(http.Request, out var fmt2) && string.Equals(fmt2, "json", StringComparison.OrdinalIgnoreCase))
                || Accepts(http.Request, "application/json");

                try
                {
                    var counts = new Dictionary<string, int>();

                    // Retry a few times to allow emulator to finish creating resources
                    for (int attempt = 0; attempt < 3; attempt++)
                    {
                        try
                        {
                            await EnsureCosmosInfra(client, dbName);
                            var db = client.GetDatabase(dbName);
                            counts.Clear();
                            foreach (var containerName in new[] { "Tenants", "Users", "Categories", "Tags", "Tasks", "Settings" })
                            {
                                var container = db.GetContainer(containerName);
                                var q = new QueryDefinition("SELECT VALUE COUNT(1) FROM c");
                                using var it = container.GetItemQueryIterator<int>(q);
                                var page = await it.ReadNextAsync();
                                counts[containerName] = page.FirstOrDefault();
                            }
                            break; // success
                        }
                        catch (CosmosException cex) when (cex.StatusCode == System.Net.HttpStatusCode.NotFound)
                        {
                            // Containers may not be visible yet; wait and retry
                            await Task.Delay(TimeSpan.FromSeconds(1 + attempt));
                            continue;
                        }
                    }

                    var payload = new { database = dbName, counts };

                    if (wantsHtml && !wantsJson)
                    {
                        // Render a simple HTML table for readability in the browser
                        var rows = string.Join("", counts.Select(kvp => $"<tr><td>{kvp.Key}</td><td style='text-align:right'>{kvp.Value}</td></tr>"));
                        var sb = new System.Text.StringBuilder();
                        sb.Append("<!doctype html><html><head><meta charset='utf-8'><title>Seed Status</title>");
                        sb.Append("<style>body{font-family:Segoe UI,Tahoma,Arial,sans-serif;margin:1.5rem}table{border-collapse:collapse;margin-top:.5rem}th,td{padding:.45rem .6rem;border:1px solid #ddd}th{background:#f7f7f7}</style>");
                        sb.Append("</head><body>");
                        sb.Append("<h2>Seed Status</h2>");
                        sb.Append("<p><a href='/'>&larr; Home</a> | <a href='/dev/init-cosmos?format=html'>Init Cosmos</a></p>");
                        sb.Append($"<p><strong>Database:</strong> {dbName}</p>");
                        sb.Append($"<table><thead><tr><th>Container</th><th>Count</th></tr></thead><tbody>{rows}</tbody></table>");
                        sb.Append("<p style='margin-top:1rem;color:#666'>Tip: add <code>?format=json</code> for pretty JSON.</p>");
                        sb.Append("</body></html>");
                        return Results.Content(sb.ToString(), "text/html");
                    }

                    return Results.Json(payload, new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
                }
                catch (Exception ex)
                {
                    var payload = new { database = dbName, error = ex.Message };

                    if (wantsHtml && !wantsJson)
                    {
                        var sb = new System.Text.StringBuilder();
                        sb.Append("<!doctype html><html><head><meta charset='utf-8'><title>Seed Status</title>");
                        sb.Append("<style>body{font-family:Segoe UI,Tahoma,Arial,sans-serif;margin:1.5rem}</style></head><body>");
                        sb.Append("<h2>Seed Status</h2>");
                        sb.Append("<p><a href='/'>&larr; Home</a> | <a href='/dev/init-cosmos?format=html'>Init Cosmos</a></p>");
                        sb.Append($"<p><strong>Database:</strong> {dbName}</p>");
                        sb.Append($"<p style='color:#b00'><strong>Error:</strong> {ex.Message}</p>");
                        sb.Append("<p style='margin-top:1rem;color:#666'>Tip: add <code>?format=json</code> for pretty JSON.</p>");
                        sb.Append("</body></html>");
                        return Results.Content(sb.ToString(), "text/html");
                    }

                    return Results.Json(payload, new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
                }
            });

            // (legacy /dev/seed-sync and GraphQL file execution removed in favor of JSON fixtures only)

            app.MapGet("/dev/init-cosmos", async (HttpContext http, IConfiguration cfg, CosmosClient client) =>
            {
                var dbName = cfg["CosmosDb:DatabaseName"] ?? "TaskTrackerDb";
                var wantsHtml = (TryGetFormat(http.Request, out var fmt) && string.Equals(fmt, "html", StringComparison.OrdinalIgnoreCase))
                                || Accepts(http.Request, "text/html");
                var wantsJson = (TryGetFormat(http.Request, out var fmt2) && string.Equals(fmt2, "json", StringComparison.OrdinalIgnoreCase))
                                || Accepts(http.Request, "application/json");

                try
                {
                    await EnsureCosmosInfra(client, dbName);
                    var payload = new { database = dbName, status = "initialized" };
                    if (wantsHtml && !wantsJson)
                    {
                        var sb = new System.Text.StringBuilder();
                        sb.Append("<!doctype html><html><head><meta charset='utf-8'><title>Init Cosmos</title>");
                        sb.Append("<style>body{font-family:Segoe UI,Tahoma,Arial,sans-serif;margin:1.5rem}</style></head><body>");
                        sb.Append("<h2>Init Cosmos</h2>");
                        sb.Append("<p><a href='/'>&larr; Home</a> | <a href='/dev/seed-status?format=html'>Seed Status</a></p>");
                        sb.Append($"<p><strong>Database:</strong> {dbName}</p>");
                        sb.Append("<p>Database and containers have been initialized if missing.</p>");
                        sb.Append("<p style='margin-top:1rem;color:#666'>Tip: add <code>?format=json</code> for JSON.</p>");
                        sb.Append("</body></html>");
                        return Results.Content(sb.ToString(), "text/html");
                    }
                    return Results.Json(payload, new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
                }
                catch (Exception ex)
                {
                    var payload = new { database = dbName, error = ex.Message };
                    if (wantsHtml && !wantsJson)
                    {
                        var sb = new System.Text.StringBuilder();
                        sb.Append("<!doctype html><html><head><meta charset='utf-8'><title>Init Cosmos</title>");
                        sb.Append("<style>body{font-family:Segoe UI,Tahoma,Arial,sans-serif;margin:1.5rem}</style></head><body>");
                        sb.Append("<h2>Init Cosmos</h2>");
                        sb.Append("<p><a href='/'>&larr; Home</a> | <a href='/dev/seed-status?format=html'>Seed Status</a></p>");
                        sb.Append($"<p><strong>Database:</strong> {dbName}</p>");
                        sb.Append($"<p style='color:#b00'><strong>Error:</strong> {ex.Message}</p>");
                        sb.Append("<p style='margin-top:1rem;color:#666'>Tip: add <code>?format=json</code> for JSON.</p>");
                        sb.Append("</body></html>");
                        return Results.Content(sb.ToString(), "text/html");
                    }
                    return Results.Json(payload, new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
                }
            });

            // Dev-only: exercise a sample Replace update against the first task to validate serialization/PK
            app.MapPost("/dev/test-update", async (IConfiguration cfg, CosmosClient client) =>
            {
                var dbName = cfg["CosmosDb:DatabaseName"] ?? "TaskTrackerDb";
                await EnsureCosmosInfra(client, dbName);
                var tasks = client.GetContainer(dbName, "Tasks");

                // Find one task id + tenantId
                using var it = tasks.GetItemQueryIterator<dynamic>(
                    new QueryDefinition("SELECT TOP 1 c.id, c.tenantId FROM c"));
                if (!it.HasMoreResults)
                {
                    return Results.NotFound(new { message = "No tasks found to update." });
                }
                var page = await it.ReadNextAsync();
                var first = page.FirstOrDefault();
                if (first == null)
                {
                    return Results.NotFound(new { message = "No tasks found to update." });
                }

                string id = first.id;
                string tenantId = first.tenantId;

                // Read strongly typed, modify, and replace
                var read = await tasks.ReadItemAsync<TaskTracker.Blazor.Models.TaskItem>(id, new PartitionKey(tenantId));
                var taskItem = read.Resource;
                var originalTitle = taskItem.Title;
                taskItem.Title = originalTitle + " [updated]";
                taskItem.UpdatedAtUtc = DateTime.UtcNow;

                var replaced = await tasks.ReplaceItemAsync(taskItem, id, new PartitionKey(tenantId));

                return Results.Ok(new
                {
                    id,
                    tenantId,
                    before = originalTitle,
                    after = replaced.Resource.Title,
                    updatedAtUtc = replaced.Resource.UpdatedAtUtc
                });
            });
        }

    app.MapRazorPages();
    app.MapBlazorHub();
    app.MapFallbackToPage("/_Host");

    // Initialize database containers after app starts (non-blocking). Set SkipCosmosInit=true to disable.
    if (!app.Configuration.GetValue<bool>("SkipCosmosInit"))
        {
            app.Lifetime.ApplicationStarted.Register(() =>
            {
        _ = Task.Run(async () => await InitializeCosmosDb(app.Services));
            });
        }

    // GraphQL (HotChocolate) is the only DAL API surface in this project

    await app.RunAsync();
    }

    // Helper methods
    static async Task InitializeCosmosDb(IServiceProvider services)
    {
        using var scope = services.CreateScope();
        var cosmosClient = scope.ServiceProvider.GetRequiredService<CosmosClient>();
        var configuration = scope.ServiceProvider.GetRequiredService<IConfiguration>();
        var seeder = scope.ServiceProvider.GetRequiredService<ISeederService>();
        var logger = scope.ServiceProvider.GetService<ILoggerFactory>()?.CreateLogger("Startup");

        var databaseName = configuration["CosmosDb:DatabaseName"] ?? "TaskTrackerDb";
    var seedOnStartup = configuration.GetValue<bool>("SeedOnStartup");
    var jsonSeedPath = configuration["Seed:JsonPath"];
    if (string.IsNullOrWhiteSpace(jsonSeedPath))
    {
        // Default for containers
        var containerDefault = "/app/seed";
        // If running outside a container (development), prefer local relative seed folder
    var localDefault = System.IO.Path.Combine(AppContext.BaseDirectory, "seed");
        jsonSeedPath = Directory.Exists(containerDefault) ? containerDefault : (Directory.Exists(localDefault) ? localDefault : containerDefault);
    }

    // Basic retry to allow emulator to come up (emulator can take ~30-60s)
    var attempts = 0;
    while (attempts < 40)
        {
            try
            {
        await EnsureCosmosInfra(cosmosClient, databaseName);

                logger?.LogInformation("Cosmos DB containers initialized successfully.");

                // Seed from JSON fixtures if enabled
                if (seedOnStartup && Directory.Exists(jsonSeedPath))
                {
                    try
                    {
                        var report = await seeder.SeedFromJsonFilesAsync(jsonSeedPath, databaseName);
                        logger?.LogInformation("JSON seed completed. Path={Path} Tenants={Tenants} Users={Users} Categories={Categories} Tags={Tags} Tasks={Tasks} Settings={Settings}",
                            report.Path, report.Tenants, report.Users, report.Categories, report.Tags, report.Tasks, report.Settings);
                    }
                    catch (Exception sex)
                    {
                        logger?.LogWarning(sex, "JSON seed failed: {Message}", sex.Message);
                    }
                }
                break;
            }
            catch (Exception ex)
            {
                attempts++;
                logger?.LogWarning(ex, "Attempt {Attempt} to initialize Cosmos DB failed: {Message}", attempts, ex.Message);
                // Allow extra time for the emulator to fully start up
                await Task.Delay(TimeSpan.FromSeconds(5));
            }
        }
    }

    static async Task EnsureCosmosInfra(CosmosClient cosmosClient, string databaseName)
    {
        // Create database if it doesn't exist
        var database = await cosmosClient.CreateDatabaseIfNotExistsAsync(databaseName);

        // Create containers idempotently
        await database.Database.CreateContainerIfNotExistsAsync("Tasks", "/tenantId");
        await database.Database.CreateContainerIfNotExistsAsync("Categories", "/tenantId");
        await database.Database.CreateContainerIfNotExistsAsync("Tags", "/tenantId");
        await database.Database.CreateContainerIfNotExistsAsync("Tenants", "/id");
    await database.Database.CreateContainerIfNotExistsAsync("Users", "/tenantId");
    await database.Database.CreateContainerIfNotExistsAsync("Settings", "/tenantId");
    }

    // (legacy SeedDemoData removed; JSON fixtures are the single source for seeding)

    // Request DTOs
    public record SASRequest(Guid TaskId, string FileName);

    // Helper: parse `?format=` query in a nullable-safe way
    private static bool TryGetFormat(HttpRequest request, [NotNullWhen(true)] out string? format)
    {
        if (request.Query.TryGetValue("format", out var fmt) && !string.IsNullOrWhiteSpace(fmt))
        {
            format = fmt.ToString();
            return true;
        }
        format = null;
        return false;
    }

    // Helper: check Accept header for a media type safely
    private static bool Accepts(HttpRequest request, string mediaType)
    {
        var accepts = request.Headers.Accept;
        if (accepts == Microsoft.Extensions.Primitives.StringValues.Empty || !accepts.Any())
            return false;
        foreach (var a in accepts)
        {
            if (!string.IsNullOrEmpty(a) && a.Contains(mediaType, StringComparison.OrdinalIgnoreCase))
                return true;
        }
        return false;
    }
}