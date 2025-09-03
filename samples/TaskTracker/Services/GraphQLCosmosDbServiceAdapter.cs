using TaskTracker.Blazor.Models;

namespace TaskTracker.Blazor.Services;

/// <summary>
/// Adapter that implements ICosmosDbService interface using GraphQL service
/// This allows the UI components to work with either direct Cosmos DB or GraphQL without changes
/// </summary>
public class GraphQLCosmosDbServiceAdapter : ICosmosDbService
{
    private readonly IGraphQLService _graphqlService;

    public GraphQLCosmosDbServiceAdapter(IGraphQLService graphqlService)
    {
        _graphqlService = graphqlService;
    }

    public async Task<IEnumerable<TaskItem>> GetTasksAsync(string tenantId, bool includeArchived = false)
    {
        return await _graphqlService.GetTasksAsync(tenantId, includeArchived);
    }

    public async Task<TaskItem?> GetTaskAsync(Guid id, string tenantId)
    {
        return await _graphqlService.GetTaskAsync(id, tenantId);
    }

    public async Task<TaskItem> CreateTaskAsync(TaskItem task)
    {
        return await _graphqlService.CreateTaskAsync(task);
    }

    public Task<TaskItem> UpdateTaskAsync(TaskItem task) => _graphqlService.UpdateTaskAsync(task);

    public Task DeleteTaskAsync(Guid id, string tenantId) => _graphqlService.DeleteTaskAsync(id, tenantId);

    public async Task<IEnumerable<Category>> GetCategoriesAsync(string tenantId)
    {
        return await _graphqlService.GetCategoriesAsync(tenantId);
    }

    public Task<Category> CreateCategoryAsync(Category category) => _graphqlService.CreateCategoryAsync(category);

    public Task<Category> UpdateCategoryAsync(Category category) => _graphqlService.CreateCategoryAsync(category);

    public Task DeleteCategoryAsync(Guid id, string tenantId)
    {
        // This would need to be implemented in GraphQL service
        return Task.FromException(new NotImplementedException("Category deletion not implemented in GraphQL service yet"));
    }

    public Task<IEnumerable<TaskTracker.Blazor.Models.Tag>> GetTagsAsync(string tenantId) => _graphqlService.GetTagsAsync(tenantId);

    public Task<TaskTracker.Blazor.Models.Tag> CreateTagAsync(TaskTracker.Blazor.Models.Tag tag) => _graphqlService.CreateTagAsync(tag);

    public Task<Tenant?> GetTenantAsync(string tenantId)
    {
        // For now, return a mock tenant
        var tenant = new Tenant
        {
            Id = tenantId,
            Name = tenantId switch
            {
                "tenant-contoso" => "Contoso North",
                "tenant-fabrikam" => "Fabrikam Corp",
                "tenant-adventure-works" => "Adventure Works",
                _ => "Demo Company"
            },
            PrimaryColor = "#0078d4",
            IsActive = true,
            CreatedAtUtc = DateTime.UtcNow
        };
        return Task.FromResult<Tenant?>(tenant);
    }

    public Task<IEnumerable<UserProfile>> GetTenantUsersAsync(string tenantId) => _graphqlService.GetTenantUsersAsync(tenantId);

    // Site settings not yet exposed via GraphQL; provide local stubs for UI compatibility
    public Task<SiteSettings?> GetSiteSettingsAsync(string tenantId)
    {
        // Return null so UI falls back to default/tenant-based values
        return Task.FromResult<SiteSettings?>(null);
    }

    public Task<SiteSettings> UpsertSiteSettingsAsync(SiteSettings settings)
    {
        // Not supported via GraphQL yet
        throw new NotImplementedException("Site settings not implemented in GraphQL service");
    }
}