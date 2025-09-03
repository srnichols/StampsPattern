using Microsoft.Azure.Cosmos;
using TaskTracker.Blazor.Models;
using System.Net;
using System.Security.Authentication;
using Microsoft.Extensions.Logging;
using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace TaskTracker.Blazor.Services;

public interface ICosmosDbService
{
    Task<IEnumerable<TaskItem>> GetTasksAsync(string tenantId, bool includeArchived = false);
    Task<TaskItem?> GetTaskAsync(Guid id, string tenantId);
    Task<TaskItem> CreateTaskAsync(TaskItem task);
    Task<TaskItem> UpdateTaskAsync(TaskItem task);
    Task DeleteTaskAsync(Guid id, string tenantId);
    Task<IEnumerable<Category>> GetCategoriesAsync(string tenantId);
    Task<Category> CreateCategoryAsync(Category category);
    Task<Category> UpdateCategoryAsync(Category category);
    Task DeleteCategoryAsync(Guid id, string tenantId);
    Task<IEnumerable<TaskTracker.Blazor.Models.Tag>> GetTagsAsync(string tenantId);
    Task<TaskTracker.Blazor.Models.Tag> CreateTagAsync(TaskTracker.Blazor.Models.Tag tag);
    Task<Tenant?> GetTenantAsync(string tenantId);
    Task<IEnumerable<UserProfile>> GetTenantUsersAsync(string tenantId);
    Task<SiteSettings?> GetSiteSettingsAsync(string tenantId);
    Task<SiteSettings> UpsertSiteSettingsAsync(SiteSettings settings);
}

public class CosmosDbService : ICosmosDbService
{
    private static readonly ActivitySource Activity = new("TaskTracker.Blazor.Cosmos");
    private static readonly Meter Meter = new("TaskTracker.Blazor", "1.0.0");
    private static readonly Counter<long> TasksReadCounter = Meter.CreateCounter<long>("cosmos.tasks.read");
    private static readonly Counter<long> TasksCreatedCounter = Meter.CreateCounter<long>("cosmos.tasks.created");
    private static readonly Counter<long> TasksUpdatedCounter = Meter.CreateCounter<long>("cosmos.tasks.updated");
    private static readonly Counter<long> TasksDeletedCounter = Meter.CreateCounter<long>("cosmos.tasks.deleted");
    private static readonly Counter<long> CategoriesReadCounter = Meter.CreateCounter<long>("cosmos.categories.read");
    private static readonly Counter<long> TagsReadCounter = Meter.CreateCounter<long>("cosmos.tags.read");
    private readonly CosmosClient _cosmosClient;
    private readonly Container _tasksContainer;
    private readonly Container _categoriesContainer;
    private readonly Container _tagsContainer;
    private readonly Container _tenantsContainer;
    private readonly Container _usersContainer;
    private readonly Container _settingsContainer;
    private readonly ILogger<CosmosDbService>? _logger;

    public CosmosDbService(CosmosClient cosmosClient, IConfiguration configuration, ILogger<CosmosDbService>? logger = null)
    {
        _cosmosClient = cosmosClient;
        _logger = logger;
        var databaseName = configuration["CosmosDb:DatabaseName"] ?? "TaskTrackerDb";
        
        _tasksContainer = _cosmosClient.GetContainer(databaseName, "Tasks");
        _categoriesContainer = _cosmosClient.GetContainer(databaseName, "Categories");
        _tagsContainer = _cosmosClient.GetContainer(databaseName, "Tags");
        _tenantsContainer = _cosmosClient.GetContainer(databaseName, "Tenants");
        _usersContainer = _cosmosClient.GetContainer(databaseName, "Users");
    _settingsContainer = _cosmosClient.GetContainer(databaseName, "Settings");
    }

    public async Task<IEnumerable<TaskItem>> GetTasksAsync(string tenantId, bool includeArchived = false)
    {
    using var activity = Activity.StartActivity("Cosmos.GetTasks", ActivityKind.Client);
    activity?.SetTag("db.system", "cosmosdb");
    activity?.SetTag("db.operation", "query");
    activity?.SetTag("db.cosmosdb.container", "Tasks");
    activity?.SetTag("cosmosdb.tenantId", tenantId);
    activity?.SetTag("app.includeArchived", includeArchived);
    try
        {
            var queryDefinition = includeArchived
                ? new QueryDefinition("SELECT * FROM c WHERE c.tenantId = @tenantId ORDER BY c.updatedAtUtc DESC")
                    .WithParameter("@tenantId", tenantId)
                : new QueryDefinition("SELECT * FROM c WHERE c.tenantId = @tenantId AND c.isArchived = false ORDER BY c.updatedAtUtc DESC")
                    .WithParameter("@tenantId", tenantId);

            var queryIterator = _tasksContainer.GetItemQueryIterator<TaskItem>(queryDefinition);
            var results = new List<TaskItem>();

            while (queryIterator.HasMoreResults)
            {
                var response = await queryIterator.ReadNextAsync();
                results.AddRange(response.ToList());
            }

            TasksReadCounter.Add(results.Count, new KeyValuePair<string, object?>("tenantId", tenantId));
            activity?.SetTag("app.results", results.Count);
            return results;
        }
        catch (Exception ex)
        {
            // Emulator not reachable / TLS error; return empty list to keep UI responsive
            _logger?.LogWarning(ex, "GetTasksAsync failed for TenantId={TenantId}, includeArchived={IncludeArchived}. Returning empty list.", tenantId, includeArchived);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            return Enumerable.Empty<TaskItem>();
        }
    }

    public async Task<TaskItem?> GetTaskAsync(Guid id, string tenantId)
    {
        using var activity = Activity.StartActivity("Cosmos.GetTask", ActivityKind.Client);
        activity?.SetTag("db.system", "cosmosdb");
        activity?.SetTag("db.operation", "read");
        activity?.SetTag("db.cosmosdb.container", "Tasks");
        activity?.SetTag("cosmosdb.tenantId", tenantId);
        activity?.SetTag("cosmosdb.id", id);
        try
        {
            var response = await _tasksContainer.ReadItemAsync<TaskItem>(id.ToString(), new PartitionKey(tenantId));
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            _logger?.LogInformation(ex, "GetTaskAsync not found. Id={Id} TenantId={TenantId}", id, tenantId);
            activity?.SetStatus(ActivityStatusCode.Ok, "not_found");
            return null;
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "GetTaskAsync failed. Id={Id} TenantId={TenantId}", id, tenantId);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            throw;
        }
    }

    public async Task<TaskItem> CreateTaskAsync(TaskItem task)
    {
        task.CreatedAtUtc = DateTime.UtcNow;
        task.UpdatedAtUtc = DateTime.UtcNow;
        using var activity = Activity.StartActivity("Cosmos.CreateTask", ActivityKind.Client);
        activity?.SetTag("db.system", "cosmosdb");
        activity?.SetTag("db.operation", "create");
        activity?.SetTag("db.cosmosdb.container", "Tasks");
        activity?.SetTag("cosmosdb.tenantId", task.TenantId);
        activity?.SetTag("cosmosdb.id", task.Id);
        try
        {
            var response = await _tasksContainer.CreateItemAsync(task, new PartitionKey(task.TenantId));
            TasksCreatedCounter.Add(1, new KeyValuePair<string, object?>("tenantId", task.TenantId));
            return response.Resource;
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "CreateTaskAsync failed. TenantId={TenantId} TaskId={TaskId}", task.TenantId, task.Id);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            throw;
        }
    }

    public async Task<TaskItem> UpdateTaskAsync(TaskItem task)
    {
        task.UpdatedAtUtc = DateTime.UtcNow;
        using var activity = Activity.StartActivity("Cosmos.UpdateTask", ActivityKind.Client);
        activity?.SetTag("db.system", "cosmosdb");
        activity?.SetTag("db.operation", "replace");
        activity?.SetTag("db.cosmosdb.container", "Tasks");
        activity?.SetTag("cosmosdb.tenantId", task.TenantId);
        activity?.SetTag("cosmosdb.id", task.Id);
        try
        {
            // Prefer replace for existing items to avoid upsert edge cases in emulator
            var response = await _tasksContainer.ReplaceItemAsync(task, task.Id.ToString(), new PartitionKey(task.TenantId));
            TasksUpdatedCounter.Add(1, new KeyValuePair<string, object?>("tenantId", task.TenantId));
            return response.Resource;
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "UpdateTaskAsync failed. TenantId={TenantId} TaskId={TaskId}", task.TenantId, task.Id);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            throw;
        }
    }

    public async Task DeleteTaskAsync(Guid id, string tenantId)
    {
        using var activity = Activity.StartActivity("Cosmos.DeleteTask", ActivityKind.Client);
        activity?.SetTag("db.system", "cosmosdb");
        activity?.SetTag("db.operation", "delete");
        activity?.SetTag("db.cosmosdb.container", "Tasks");
        activity?.SetTag("cosmosdb.tenantId", tenantId);
        activity?.SetTag("cosmosdb.id", id);
        try
        {
            await _tasksContainer.DeleteItemAsync<TaskItem>(id.ToString(), new PartitionKey(tenantId));
            TasksDeletedCounter.Add(1, new KeyValuePair<string, object?>("tenantId", tenantId));
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            _logger?.LogInformation(ex, "DeleteTaskAsync not found. Id={Id} TenantId={TenantId}", id, tenantId);
            activity?.SetStatus(ActivityStatusCode.Ok, "not_found");
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "DeleteTaskAsync failed. Id={Id} TenantId={TenantId}", id, tenantId);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            throw;
        }
    }

    public async Task<IEnumerable<Category>> GetCategoriesAsync(string tenantId)
    {
    using var activity = Activity.StartActivity("Cosmos.GetCategories", ActivityKind.Client);
    activity?.SetTag("db.system", "cosmosdb");
    activity?.SetTag("db.operation", "query");
    activity?.SetTag("db.cosmosdb.container", "Categories");
    activity?.SetTag("cosmosdb.tenantId", tenantId);
    try
        {
            var queryDefinition = new QueryDefinition("SELECT * FROM c WHERE c.tenantId = @tenantId ORDER BY c.sortOrder, c.name")
                .WithParameter("@tenantId", tenantId);

            var queryIterator = _categoriesContainer.GetItemQueryIterator<Category>(queryDefinition);
            var results = new List<Category>();

            while (queryIterator.HasMoreResults)
            {
                var response = await queryIterator.ReadNextAsync();
                results.AddRange(response.ToList());
            }

            CategoriesReadCounter.Add(results.Count, new KeyValuePair<string, object?>("tenantId", tenantId));
            activity?.SetTag("app.results", results.Count);
            return results;
        }
        catch (Exception ex)
        {
            _logger?.LogWarning(ex, "GetCategoriesAsync failed for TenantId={TenantId}. Returning empty list.", tenantId);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            return Enumerable.Empty<Category>();
        }
    }

    public async Task<Category> CreateCategoryAsync(Category category)
    {
        category.CreatedAtUtc = DateTime.UtcNow;
        try
        {
            var response = await _categoriesContainer.CreateItemAsync(category, new PartitionKey(category.TenantId));
            return response.Resource;
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "CreateCategoryAsync failed. TenantId={TenantId} CategoryId={CategoryId}", category.TenantId, category.Id);
            throw;
        }
    }

    public async Task<Category> UpdateCategoryAsync(Category category)
    {
        try
        {
            var response = await _categoriesContainer.UpsertItemAsync(category, new PartitionKey(category.TenantId));
            return response.Resource;
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "UpdateCategoryAsync failed. TenantId={TenantId} CategoryId={CategoryId}", category.TenantId, category.Id);
            throw;
        }
    }

    public async Task DeleteCategoryAsync(Guid id, string tenantId)
    {
        await _categoriesContainer.DeleteItemAsync<Category>(id.ToString(), new PartitionKey(tenantId));
    }

    public async Task<IEnumerable<TaskTracker.Blazor.Models.Tag>> GetTagsAsync(string tenantId)
    {
    using var activity = Activity.StartActivity("Cosmos.GetTags", ActivityKind.Client);
    activity?.SetTag("db.system", "cosmosdb");
    activity?.SetTag("db.operation", "query");
    activity?.SetTag("db.cosmosdb.container", "Tags");
    activity?.SetTag("cosmosdb.tenantId", tenantId);
    try
        {
            var queryDefinition = new QueryDefinition("SELECT * FROM c WHERE c.tenantId = @tenantId ORDER BY c.name")
                .WithParameter("@tenantId", tenantId);

            var queryIterator = _tagsContainer.GetItemQueryIterator<TaskTracker.Blazor.Models.Tag>(queryDefinition);
            var results = new List<TaskTracker.Blazor.Models.Tag>();

            while (queryIterator.HasMoreResults)
            {
                var response = await queryIterator.ReadNextAsync();
                results.AddRange(response.ToList());
            }

            TagsReadCounter.Add(results.Count, new KeyValuePair<string, object?>("tenantId", tenantId));
            activity?.SetTag("app.results", results.Count);
            return results;
        }
        catch (Exception)
        {
            return Enumerable.Empty<TaskTracker.Blazor.Models.Tag>();
        }
    }

    public async Task<TaskTracker.Blazor.Models.Tag> CreateTagAsync(TaskTracker.Blazor.Models.Tag tag)
    {
        tag.CreatedAtUtc = DateTime.UtcNow;
        
        var response = await _tagsContainer.CreateItemAsync(tag, new PartitionKey(tag.TenantId));
        return response.Resource;
    }

    public async Task<Tenant?> GetTenantAsync(string tenantId)
    {
        try
        {
            var response = await _tenantsContainer.ReadItemAsync<Tenant>(tenantId, new PartitionKey(tenantId));
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            return null;
        }
        catch (Exception)
        {
            // Emulator not reachable / TLS error
            return null;
        }
    }

    public async Task<IEnumerable<UserProfile>> GetTenantUsersAsync(string tenantId)
    {
        try
        {
            try
            {
                var queryDefinition = new QueryDefinition("SELECT * FROM c WHERE c.tenantId = @tenantId ORDER BY c.displayName")
                    .WithParameter("@tenantId", tenantId);

                var queryIterator = _usersContainer.GetItemQueryIterator<UserProfile>(queryDefinition);
                var results = new List<UserProfile>();

                while (queryIterator.HasMoreResults)
                {
                    var response = await queryIterator.ReadNextAsync();
                    results.AddRange(response.ToList());
                }

                return results;
            }
            catch (Exception)
            {
                return Enumerable.Empty<UserProfile>();
            }
        }
        catch (HttpRequestException)
        {
            return Enumerable.Empty<UserProfile>();
        }
        catch (AuthenticationException)
        {
            return Enumerable.Empty<UserProfile>();
        }
    }

    public async Task<SiteSettings?> GetSiteSettingsAsync(string tenantId)
    {
        try
        {
            var response = await _settingsContainer.ReadItemAsync<SiteSettings>("settings", new PartitionKey(tenantId));
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            return null;
        }
        catch
        {
            return null;
        }
    }

    public async Task<SiteSettings> UpsertSiteSettingsAsync(SiteSettings settings)
    {
    settings.UpdatedAtUtc = DateTime.UtcNow;
    if (string.IsNullOrWhiteSpace(settings.TenantId)) throw new ArgumentException("TenantId is required for SiteSettings");
    settings.Id = "settings";
    var response = await _settingsContainer.UpsertItemAsync(settings, new PartitionKey(settings.TenantId));
        return response.Resource;
    }
}