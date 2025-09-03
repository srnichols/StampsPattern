using TaskTracker.Blazor.Models;

namespace TaskTracker.Blazor.Services;

public interface IGraphQLService
{
    Task<IEnumerable<TaskItem>> GetTasksAsync(string tenantId, bool includeArchived = false);
    Task<TaskItem?> GetTaskAsync(Guid id, string tenantId);
    Task<TaskItem> CreateTaskAsync(TaskItem task);
    Task<TaskItem> UpdateTaskAsync(TaskItem task);
    Task DeleteTaskAsync(Guid id, string tenantId);
    Task<IEnumerable<Category>> GetCategoriesAsync(string tenantId);
    Task<Category> CreateCategoryAsync(Category category);
    Task<IEnumerable<TaskTracker.Blazor.Models.Tag>> GetTagsAsync(string tenantId);
    Task<TaskTracker.Blazor.Models.Tag> CreateTagAsync(TaskTracker.Blazor.Models.Tag tag);
    Task<IEnumerable<UserProfile>> GetTenantUsersAsync(string tenantId);
}
