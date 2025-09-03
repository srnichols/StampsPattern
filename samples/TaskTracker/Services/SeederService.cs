using System.Text.Json;
using Microsoft.Azure.Cosmos;
using TaskTracker.Blazor.Models;

namespace TaskTracker.Blazor.Services;

public interface ISeederService
{
    Task<SeedReport> SeedFromJsonFilesAsync(string rootPath, string databaseName);
}

public record SeedReport(
    string Path,
    int Tenants,
    int Users,
    int Categories,
    int Tags,
    int Tasks,
    int Settings,
    List<string> Errors
);

public class SeederService : ISeederService
{
    private readonly CosmosClient _cosmos;

    public SeederService(CosmosClient cosmos)
    {
        _cosmos = cosmos;
    }

    public async Task<SeedReport> SeedFromJsonFilesAsync(string rootPath, string databaseName)
    {
        var errors = new List<string>();
    // Ensure database exists before creating containers
    var dbResponse = await _cosmos.CreateDatabaseIfNotExistsAsync(databaseName);
    var db = dbResponse.Database;

        // Ensure containers (idempotent)
    await db.CreateContainerIfNotExistsAsync("Tasks", "/tenantId");
    await db.CreateContainerIfNotExistsAsync("Categories", "/tenantId");
    await db.CreateContainerIfNotExistsAsync("Tags", "/tenantId");
    await db.CreateContainerIfNotExistsAsync("Tenants", "/id");
    await db.CreateContainerIfNotExistsAsync("Users", "/tenantId");
    await db.CreateContainerIfNotExistsAsync("Settings", "/tenantId");

        var tenantsC = db.GetContainer("Tenants");
        var usersC = db.GetContainer("Users");
        var categoriesC = db.GetContainer("Categories");
        var tagsC = db.GetContainer("Tags");
        var tasksC = db.GetContainer("Tasks");
        var settingsC = db.GetContainer("Settings");

        int tenants = 0, users = 0, categories = 0, tags = 0, tasks = 0, settings = 0;

        async Task UpsertManyAsync<T>(string file, Func<T, PartitionKey> pk, Container container, Action<T>? normalize = null)
        {
            var path = System.IO.Path.Combine(rootPath, file);
            if (!File.Exists(path)) return;
            try
            {
                var json = await File.ReadAllTextAsync(path);
                var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var list = JsonSerializer.Deserialize<List<T>>(json, options) ?? new List<T>();
                foreach (var item in list)
                {
                    normalize?.Invoke(item);
                    await container.UpsertItemAsync(item, pk(item));
                }
                if (typeof(T) == typeof(Tenant)) tenants += list.Count;
                else if (typeof(T) == typeof(UserProfile)) users += list.Count;
                else if (typeof(T) == typeof(Category)) categories += list.Count;
                else if (typeof(T) == typeof(TaskTracker.Blazor.Models.Tag)) tags += list.Count;
                else if (typeof(T) == typeof(TaskItem)) tasks += list.Count;
                else if (typeof(T) == typeof(SiteSettings)) settings += list.Count;
            }
            catch (Exception ex)
            {
                errors.Add($"{file}: {ex.Message}");
            }
        }

        // Tenants
        await UpsertManyAsync<Tenant>(
            "tenants.json",
            t => new PartitionKey(t.Id),
            tenantsC,
            t => { if (t.CreatedAtUtc == default) t.CreatedAtUtc = DateTime.UtcNow; }
        );

        // Users
        await UpsertManyAsync<UserProfile>(
            "users.json",
            u => new PartitionKey(u.TenantId),
            usersC,
            u => {
                if (string.IsNullOrWhiteSpace(u.Id)) u.Id = Guid.NewGuid().ToString();
                if (u.CreatedAtUtc == default) u.CreatedAtUtc = DateTime.UtcNow;
                if (u.LastLoginUtc == default) u.LastLoginUtc = DateTime.UtcNow;
            }
        );

        // Categories
        await UpsertManyAsync<Category>(
            "categories.json",
            c => new PartitionKey(c.TenantId),
            categoriesC,
            c => { if (c.Id == Guid.Empty) c.Id = Guid.NewGuid(); if (c.CreatedAtUtc == default) c.CreatedAtUtc = DateTime.UtcNow; }
        );

        // Tags
        await UpsertManyAsync<TaskTracker.Blazor.Models.Tag>(
            "tags.json",
            t => new PartitionKey(t.TenantId),
            tagsC,
            t => { if (t.Id == Guid.Empty) t.Id = Guid.NewGuid(); if (t.CreatedAtUtc == default) t.CreatedAtUtc = DateTime.UtcNow; }
        );

        // Settings
        await UpsertManyAsync<SiteSettings>(
            "settings.json",
            s => new PartitionKey(s.TenantId),
            settingsC,
            s => { if (string.IsNullOrWhiteSpace(s.Id)) s.Id = "settings"; if (s.UpdatedAtUtc == default) s.UpdatedAtUtc = DateTime.UtcNow; }
        );

    // Build a category lookup (tenantId + name -> id) after upserting categories
    // Use a case-insensitive composite string key: "{tenantId}|{name}"
    var categoryLookup = new Dictionary<string, Guid>(StringComparer.OrdinalIgnoreCase);
        try
        {
            using var catIter = categoriesC.GetItemQueryIterator<Category>(new QueryDefinition("SELECT c.id, c.tenantId, c.name, c.sortOrder, c.createdAtUtc FROM c"));
            while (catIter.HasMoreResults)
            {
                var page = await catIter.ReadNextAsync();
                foreach (var c in page)
                {
                    if (!string.IsNullOrWhiteSpace(c.TenantId) && !string.IsNullOrWhiteSpace(c.Name))
                    {
            categoryLookup[$"{c.TenantId}|{c.Name}"] = c.Id;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            errors.Add($"categories-lookup: {ex.Message}");
        }

        // Tasks with optional categoryName for seeding convenience
        var tasksPath = System.IO.Path.Combine(rootPath, "tasks.json");
        if (File.Exists(tasksPath))
        {
            try
            {
                var json = await File.ReadAllTextAsync(tasksPath);
                var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var seedTasks = JsonSerializer.Deserialize<List<SeedTask>>(json, options) ?? new List<SeedTask>();
                foreach (var st in seedTasks)
                {
                    // Map to TaskItem
                    var t = new TaskItem
                    {
                        Id = st.Id == Guid.Empty ? Guid.NewGuid() : st.Id,
                        TenantId = st.TenantId ?? string.Empty,
                        Title = st.Title ?? string.Empty,
                        Description = st.Description,
                        CategoryId = st.CategoryId,
                        Priority = st.Priority == 0 ? Priority.Mid : st.Priority,
                        IsArchived = st.IsArchived,
                        DueDate = st.DueDate,
                        Icon = st.Icon,
                        Attachments = st.Attachments ?? new List<Attachment>(),
                        AssigneeUserIds = st.AssigneeUserIds ?? new List<string>(),
                        CreatedByUserId = st.CreatedByUserId ?? string.Empty,
                        CreatedAtUtc = st.CreatedAtUtc == default ? DateTime.UtcNow : st.CreatedAtUtc,
                        UpdatedAtUtc = st.UpdatedAtUtc == default ? DateTime.UtcNow : st.UpdatedAtUtc,
                        TagNames = st.TagNames ?? new List<string>()
                    };

                    // Resolve category by name if not provided via Id
                    if (t.CategoryId == null && !string.IsNullOrWhiteSpace(st.CategoryName))
                    {
                        if (categoryLookup.TryGetValue($"{t.TenantId}|{st.CategoryName}", out var cid))
                        {
                            t.CategoryId = cid;
                        }
                    }

                    // Default icon from category if not set
                    if (string.IsNullOrWhiteSpace(t.Icon) && !string.IsNullOrWhiteSpace(st.CategoryName))
                    {
                        t.Icon = IconHelpers.DefaultIconForCategory(st.CategoryName!);
                    }

                    await tasksC.UpsertItemAsync(t, new PartitionKey(t.TenantId));
                    tasks++;
                }
            }
            catch (Exception ex)
            {
                errors.Add($"tasks.json: {ex.Message}");
            }
        }

        return new SeedReport(rootPath, tenants, users, categories, tags, tasks, settings, errors);
    }
}

// DTO for seeding tasks with optional categoryName resolution
file class SeedTask
{
    public Guid Id { get; set; }
    public string? TenantId { get; set; }
    public string? Title { get; set; }
    public string? Description { get; set; }
    public Guid? CategoryId { get; set; }
    public string? CategoryName { get; set; }
    public Priority Priority { get; set; }
    public bool IsArchived { get; set; }
    public DateTime? DueDate { get; set; }
    public string? Icon { get; set; }
    public List<Attachment>? Attachments { get; set; }
    public List<string>? AssigneeUserIds { get; set; }
    public string? CreatedByUserId { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
    public List<string>? TagNames { get; set; }
}

file static class SeedIconDefaults
{
    public static readonly Dictionary<string, string> Map = new(StringComparer.OrdinalIgnoreCase)
    {
        ["Backlog"] = "idea.bulb",
        ["Ideas"] = "idea.bulb",
        ["Planned"] = "planning.note",
        ["In Progress"] = "code.brackets",
        ["Executing"] = "code.brackets",
        ["Code Review"] = "review.magnifier",
        ["Testing"] = "test.lab",
        ["QA"] = "test.lab",
        ["UAT"] = "test.lab",
        ["Blocked"] = "alert.warning",
        ["Done"] = "general.check"
    };
}

static partial class IconHelpers
{
    internal static string DefaultIconForCategory(string categoryName)
        => SeedIconDefaults.Map.TryGetValue(categoryName, out var icon)
            ? icon
            : "code.brackets";
}
