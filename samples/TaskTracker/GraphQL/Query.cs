using HotChocolate;
using HotChocolate.Types;
using HotChocolate.Authorization;
using TaskTracker.Blazor.Models;
using TaskTracker.Blazor.Services;

namespace TaskTracker.Blazor.GraphQL;

[Authorize]
public class Query
{

    public async Task<IEnumerable<TaskItem>> GetTasks(
        [Service] ICosmosDbService cosmosDbService,
        string tenantId,
        bool includeArchived = false,
        int skip = 0,
        int take = 50)
    {
        var all = await cosmosDbService.GetTasksAsync(tenantId, includeArchived);
        return all.Skip(skip).Take(take);
    }

    public async Task<TaskItem?> GetTask(
        [Service] ICosmosDbService cosmosDbService,
        Guid id,
        string tenantId)
    {
        return await cosmosDbService.GetTaskAsync(id, tenantId);
    }

    public async Task<IEnumerable<Category>> GetCategories(
        [Service] ICosmosDbService cosmosDbService,
        string tenantId)
    {
        return await cosmosDbService.GetCategoriesAsync(tenantId);
    }

    public async Task<Category?> GetCategory(
        [Service] ICosmosDbService cosmosDbService,
        Guid id,
        string tenantId)
    {
        var categories = await cosmosDbService.GetCategoriesAsync(tenantId);
        return categories.FirstOrDefault(c => c.Id == id);
    }

    public async Task<IEnumerable<TaskTracker.Blazor.Models.Tag>> GetTags(
        [Service] ICosmosDbService cosmosDbService,
        string tenantId)
    {
        return await cosmosDbService.GetTagsAsync(tenantId);
    }

    public async Task<TaskTracker.Blazor.Models.Tag?> GetTag(
        [Service] ICosmosDbService cosmosDbService,
        Guid id,
        string tenantId)
    {
        var tags = await cosmosDbService.GetTagsAsync(tenantId);
        return tags.FirstOrDefault(t => t.Id == id);
    }

    public async Task<Tenant?> GetTenant(
        [Service] ICosmosDbService cosmosDbService,
        string tenantId)
    {
        return await cosmosDbService.GetTenantAsync(tenantId);
    }

    public async Task<IEnumerable<UserProfile>> GetTenantUsers(
        [Service] ICosmosDbService cosmosDbService,
        string tenantId)
    {
        return await cosmosDbService.GetTenantUsersAsync(tenantId);
    }

    public async Task<UserProfile?> GetUser(
        [Service] ICosmosDbService cosmosDbService,
        string tenantId,
        string userId)
    {
        var users = await cosmosDbService.GetTenantUsersAsync(tenantId);
        return users.FirstOrDefault(u => u.Id == userId);
    }

    // Advanced search/filter for tasks

    public async Task<IEnumerable<TaskItem>> SearchTasks(
        [Service] ICosmosDbService cosmosDbService,
        string tenantId,
        string? query = null,
        Guid? categoryId = null,
        string? tag = null,
        string? assigneeUserId = null,
        bool? isArchived = null,
        int skip = 0,
        int take = 50)
    {
        var tasks = await cosmosDbService.GetTasksAsync(tenantId, isArchived ?? false);
        var filtered = tasks.AsQueryable();
        if (!string.IsNullOrEmpty(query))
            filtered = filtered.Where(t => t.Title.Contains(query, StringComparison.OrdinalIgnoreCase) || (t.Description ?? "").Contains(query, StringComparison.OrdinalIgnoreCase));
        if (categoryId.HasValue)
            filtered = filtered.Where(t => t.CategoryId == categoryId);
        if (!string.IsNullOrEmpty(tag))
            filtered = filtered.Where(t => t.TagNames.Contains(tag));
        if (!string.IsNullOrEmpty(assigneeUserId))
            filtered = filtered.Where(t => t.AssigneeUserIds.Contains(assigneeUserId));
        return filtered.Skip(skip).Take(take).ToList();
    }

    // Simple analytics: count, overdue, etc.
    public async Task<object> GetTaskAnalytics(
        [Service] ICosmosDbService cosmosDbService,
        string tenantId)
    {
        var tasks = await cosmosDbService.GetTasksAsync(tenantId, true);
        var now = DateTime.UtcNow;
        return new {
            total = tasks.Count(),
            archived = tasks.Count(t => t.IsArchived),
            overdue = tasks.Count(t => t.DueDate.HasValue && t.DueDate.Value < now && !t.IsArchived),
            dueToday = tasks.Count(t => t.DueDate.HasValue && t.DueDate.Value.Date == now.Date && !t.IsArchived),
            byPriority = tasks.GroupBy(t => t.Priority).Select(g => new { priority = g.Key, count = g.Count() }).ToList()
        };
    }

}
