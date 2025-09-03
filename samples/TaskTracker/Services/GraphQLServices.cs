using GraphQL;
using GraphQL.Client.Http;
using GraphQL.Client.Serializer.SystemTextJson;
using TaskTracker.Blazor.Models;
using System.Text.Json;

namespace TaskTracker.Blazor.Services;



public class GraphQLService : IGraphQLService
{
    private readonly GraphQLHttpClient _client;
    private readonly IAuthenticationService _authService;
    private readonly ILogger<GraphQLService> _logger;

    public GraphQLService(IConfiguration configuration, IAuthenticationService authService, ILogger<GraphQLService> logger)
    {
        var graphqlEndpoint = configuration["GraphQL:Endpoint"] ?? "https://localhost:5001/graphql";
        _client = new GraphQLHttpClient(graphqlEndpoint, new SystemTextJsonSerializer());
        _authService = authService;
        _logger = logger;

        // Add authentication header
        _client.HttpClient.DefaultRequestHeaders.Authorization = 
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", GetAuthToken());
    }

    private string? GetAuthToken()
    {
        // In a real implementation, get the current user's JWT token
        // For now, return a placeholder
        return "placeholder-jwt-token";
    }

    public async Task<IEnumerable<TaskItem>> GetTasksAsync(string tenantId, bool includeArchived = false)
    {
        var query = new GraphQLRequest
        {
            Query = @"
                query GetTasks($tenantId: String!, $includeArchived: Boolean!) {
                    tasks(
                        filter: { 
                            tenantId: { eq: $tenantId }
                            isArchived: { eq: $includeArchived }
                        }
                        orderBy: { updatedAtUtc: DESC }
                    ) {
                        items {
                            id
                            tenantId
                            title
                            description
                            categoryId
                            priority
                            isArchived
                            dueDate
                            icon
                            attachments {
                                id
                                blobUri
                                fileName
                                contentType
                                sizeBytes
                                uploadedByUserId
                                uploadedAtUtc
                            }
                            assigneeUserIds
                            createdByUserId
                            createdAtUtc
                            updatedAtUtc
                            tagNames
                        }
                    }
                }",
            Variables = new { tenantId, includeArchived }
        };

        try
        {
            var response = await _client.SendQueryAsync<TasksResponse>(query);
            
            if (response.Errors?.Any() == true)
            {
                _logger.LogError("GraphQL errors: {Errors}", string.Join(", ", response.Errors.Select(e => e.Message)));
                return Array.Empty<TaskItem>();
            }

            return response.Data?.Tasks?.Items ?? Array.Empty<TaskItem>();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching tasks via GraphQL");
            return Array.Empty<TaskItem>();
        }
    }

    public async Task<TaskItem?> GetTaskAsync(Guid id, string tenantId)
    {
        var query = new GraphQLRequest
        {
            Query = @"
                query GetTask($id: ID!, $tenantId: String!) {
                    task(id: $id, filter: { tenantId: { eq: $tenantId } }) {
                        id
                        tenantId
                        title
                        description
                        categoryId
                        priority
                        isArchived
                        dueDate
                        icon
                        attachments {
                            id
                            blobUri
                            fileName
                            contentType
                            sizeBytes
                            uploadedByUserId
                            uploadedAtUtc
                        }
                        assigneeUserIds
                        createdByUserId
                        createdAtUtc
                        updatedAtUtc
                        tagNames
                    }
                }",
            Variables = new { id = id.ToString(), tenantId }
        };

        try
        {
            var response = await _client.SendQueryAsync<TaskResponse>(query);
            
            if (response.Errors?.Any() == true)
            {
                _logger.LogError("GraphQL errors: {Errors}", string.Join(", ", response.Errors.Select(e => e.Message)));
                return null;
            }

            return response.Data?.Task;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching task {TaskId} via GraphQL", id);
            return null;
        }
    }

    public async Task<TaskItem> CreateTaskAsync(TaskItem task)
    {
        var mutation = new GraphQLRequest
        {
            Query = @"
                mutation CreateTask($task: TaskInput!) {
                    createTask(item: $task) {
                        id
                        tenantId
                        title
                        description
                        categoryId
                        priority
                        isArchived
                        dueDate
                        icon
                        attachments {
                            id
                            blobUri
                            fileName
                            contentType
                            sizeBytes
                            uploadedByUserId
                            uploadedAtUtc
                        }
                        assigneeUserIds
                        createdByUserId
                        createdAtUtc
                        updatedAtUtc
                        tagNames
                    }
                }",
            Variables = new { task = MapToInput(task) }
        };

        try
        {
            var response = await _client.SendMutationAsync<CreateTaskResponse>(mutation);
            
            if (response.Errors?.Any() == true)
            {
                _logger.LogError("GraphQL errors: {Errors}", string.Join(", ", response.Errors.Select(e => e.Message)));
                throw new InvalidOperationException($"Failed to create task: {string.Join(", ", response.Errors.Select(e => e.Message))}");
            }

            return response.Data?.CreateTask ?? throw new InvalidOperationException("Failed to create task");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating task via GraphQL");
            throw;
        }
    }

    public async Task<TaskItem> UpdateTaskAsync(TaskItem task)
    {
        var mutation = new GraphQLRequest
        {
            Query = @"
                mutation UpdateTask($id: ID!, $task: TaskInput!) {
                    updateTask(id: $id, item: $task) {
                        id
                        tenantId
                        title
                        description
                        categoryId
                        priority
                        isArchived
                        dueDate
                        icon
                        attachments {
                            id
                            blobUri
                            fileName
                            contentType
                            sizeBytes
                            uploadedByUserId
                            uploadedAtUtc
                        }
                        assigneeUserIds
                        createdByUserId
                        createdAtUtc
                        updatedAtUtc
                        tagNames
                    }
                }",
            Variables = new { id = task.Id.ToString(), task = MapToInput(task) }
        };

        try
        {
            var response = await _client.SendMutationAsync<UpdateTaskResponse>(mutation);
            
            if (response.Errors?.Any() == true)
            {
                _logger.LogError("GraphQL errors: {Errors}", string.Join(", ", response.Errors.Select(e => e.Message)));
                throw new InvalidOperationException($"Failed to update task: {string.Join(", ", response.Errors.Select(e => e.Message))}");
            }

            return response.Data?.UpdateTask ?? throw new InvalidOperationException("Failed to update task");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating task {TaskId} via GraphQL", task.Id);
            throw;
        }
    }

    public async Task DeleteTaskAsync(Guid id, string tenantId)
    {
        var mutation = new GraphQLRequest
        {
            Query = @"
                mutation DeleteTask($id: ID!) {
                    deleteTask(id: $id) {
                        id
                    }
                }",
            Variables = new { id = id.ToString() }
        };

        try
        {
            var response = await _client.SendMutationAsync<DeleteTaskResponse>(mutation);
            
            if (response.Errors?.Any() == true)
            {
                _logger.LogError("GraphQL errors: {Errors}", string.Join(", ", response.Errors.Select(e => e.Message)));
                throw new InvalidOperationException($"Failed to delete task: {string.Join(", ", response.Errors.Select(e => e.Message))}");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting task {TaskId} via GraphQL", id);
            throw;
        }
    }

    public async Task<IEnumerable<Category>> GetCategoriesAsync(string tenantId)
    {
        var query = new GraphQLRequest
        {
            Query = @"
                query GetCategories($tenantId: String!) {
                    categories(
                        filter: { tenantId: { eq: $tenantId } }
                        orderBy: [{ sortOrder: ASC }, { name: ASC }]
                    ) {
                        items {
                            id
                            tenantId
                            name
                            sortOrder
                            createdAtUtc
                        }
                    }
                }",
            Variables = new { tenantId }
        };

        try
        {
            var response = await _client.SendQueryAsync<CategoriesResponse>(query);
            
            if (response.Errors?.Any() == true)
            {
                _logger.LogError("GraphQL errors: {Errors}", string.Join(", ", response.Errors.Select(e => e.Message)));
                return Array.Empty<Category>();
            }

            return response.Data?.Categories?.Items ?? Array.Empty<Category>();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching categories via GraphQL");
            return Array.Empty<Category>();
        }
    }

    public async Task<Category> CreateCategoryAsync(Category category)
    {
        var mutation = new GraphQLRequest
        {
            Query = @"
                mutation CreateCategory($category: CategoryInput!) {
                    createCategory(item: $category) {
                        id
                        tenantId
                        name
                        sortOrder
                        createdAtUtc
                    }
                }",
            Variables = new { category = new { category.TenantId, category.Name, category.SortOrder } }
        };

        try
        {
            var response = await _client.SendMutationAsync<CreateCategoryResponse>(mutation);
            
            if (response.Errors?.Any() == true)
            {
                _logger.LogError("GraphQL errors: {Errors}", string.Join(", ", response.Errors.Select(e => e.Message)));
                throw new InvalidOperationException($"Failed to create category: {string.Join(", ", response.Errors.Select(e => e.Message))}");
            }

            return response.Data?.CreateCategory ?? throw new InvalidOperationException("Failed to create category");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating category via GraphQL");
            throw;
        }
    }

    public async Task<IEnumerable<TaskTracker.Blazor.Models.Tag>> GetTagsAsync(string tenantId)
    {
        var query = new GraphQLRequest
        {
            Query = @"
                query GetTags($tenantId: String!) {
                    tags(
                        filter: { tenantId: { eq: $tenantId } }
                        orderBy: { name: ASC }
                    ) {
                        items {
                            id
                            tenantId
                            name
                            createdAtUtc
                        }
                    }
                }",
            Variables = new { tenantId }
        };

        try
        {
            var response = await _client.SendQueryAsync<TagsResponse>(query);
            if (response.Errors?.Any() == true)
            {
                _logger.LogError("GraphQL errors: {Errors}", string.Join(", ", response.Errors.Select(e => e.Message)));
                return Array.Empty<TaskTracker.Blazor.Models.Tag>();
            }
            return response.Data?.Tags?.Items ?? Array.Empty<TaskTracker.Blazor.Models.Tag>();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching tags via GraphQL");
            return Array.Empty<TaskTracker.Blazor.Models.Tag>();
        }
    }

    public async Task<TaskTracker.Blazor.Models.Tag> CreateTagAsync(TaskTracker.Blazor.Models.Tag tag)
    {
        var mutation = new GraphQLRequest
        {
            Query = @"
                mutation CreateTag($tag: TagInput!) {
                    createTag(item: $tag) {
                        id
                        tenantId
                        name
                        createdAtUtc
                    }
                }",
            Variables = new { tag = new { tag.TenantId, tag.Name } }
        };

        try
        {
            var response = await _client.SendMutationAsync<CreateTagResponse>(mutation);
            if (response.Errors?.Any() == true)
            {
                _logger.LogError("GraphQL errors: {Errors}", string.Join(", ", response.Errors.Select(e => e.Message)));
                throw new InvalidOperationException($"Failed to create tag: {string.Join(", ", response.Errors.Select(e => e.Message))}");
            }
            return response.Data?.CreateTag ?? throw new InvalidOperationException("Failed to create tag");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating tag via GraphQL");
            throw;
        }
    }

    public async Task<IEnumerable<UserProfile>> GetTenantUsersAsync(string tenantId)
    {
        var query = new GraphQLRequest
        {
            Query = @"
                query GetUsers($tenantId: String!) {
                    users(
                        filter: { tenantId: { eq: $tenantId } }
                        orderBy: { displayName: ASC }
                    ) {
                        items {
                            id
                            tenantId
                            displayName
                            email
                            createdAtUtc
                            lastLoginUtc
                        }
                    }
                }",
            Variables = new { tenantId }
        };

        try
        {
            var response = await _client.SendQueryAsync<UsersResponse>(query);
            
            if (response.Errors?.Any() == true)
            {
                _logger.LogError("GraphQL errors: {Errors}", string.Join(", ", response.Errors.Select(e => e.Message)));
                return Array.Empty<UserProfile>();
            }

            return response.Data?.Users?.Items ?? Array.Empty<UserProfile>();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching users via GraphQL");
            return Array.Empty<UserProfile>();
        }
    }

    private static object MapToInput(TaskItem task)
    {
        return new
        {
            task.TenantId,
            task.Title,
            task.Description,
            CategoryId = task.CategoryId?.ToString(),
            task.Priority,
            task.IsArchived,
            task.DueDate,
            task.Icon,
            task.Attachments,
            task.AssigneeUserIds,
            task.CreatedByUserId,
            task.TagNames
        };
    }

    public void Dispose()
    {
        _client?.Dispose();
    }
}

// Response DTOs for GraphQL
public class TasksResponse
{
    public TasksData? Tasks { get; set; }
}

public class TasksData
{
    public IEnumerable<TaskItem>? Items { get; set; }
}

public class TaskResponse
{
    public TaskItem? Task { get; set; }
}

public class CreateTaskResponse
{
    public TaskItem? CreateTask { get; set; }
}

public class UpdateTaskResponse
{
    public TaskItem? UpdateTask { get; set; }
}

public class DeleteTaskResponse
{
    public object? DeleteTask { get; set; }
}

public class CategoriesResponse
{
    public CategoriesData? Categories { get; set; }
}

public class CategoriesData
{
    public IEnumerable<Category>? Items { get; set; }
}

public class CreateCategoryResponse
{
    public Category? CreateCategory { get; set; }
}

public class TagsResponse
{
    public TagsData? Tags { get; set; }
}

public class TagsData
{
    public IEnumerable<TaskTracker.Blazor.Models.Tag>? Items { get; set; }
}

public class CreateTagResponse
{
    public TaskTracker.Blazor.Models.Tag? CreateTag { get; set; }
}

public class UsersResponse
{
    public UsersData? Users { get; set; }
}

public class UsersData
{
    public IEnumerable<UserProfile>? Items { get; set; }
}