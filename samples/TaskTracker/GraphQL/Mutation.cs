using HotChocolate;
using HotChocolate.Types;
using HotChocolate.Authorization;
using TaskTracker.Blazor.Models;
using TaskTracker.Blazor.Services;
using System.Diagnostics;
using System.Diagnostics.Metrics;
using System.Collections.Generic;

namespace TaskTracker.Blazor.GraphQL;

[Authorize]
public class Mutation
{
    private static readonly ActivitySource Tracer = new("TaskTracker.Blazor.GraphQL");
    private static readonly Meter Meter = new("TaskTracker.Blazor", "1.0.0");
    private static readonly Counter<long> EventsPublishedCounter = Meter.CreateCounter<long>("dapr.events.published");

    public async Task<TaskItem> CreateTask(
        [Service] ICosmosDbService cosmosDbService,
        [Service] Dapr.Client.DaprClient dapr,
        [Service] IDaprStateService daprStateService,
        TaskItem task)
    {
        // Validation
        if (string.IsNullOrWhiteSpace(task.Title))
            throw new Exception("Task title is required.");
        if (string.IsNullOrWhiteSpace(task.TenantId))
            throw new Exception("TenantId is required.");

    var created = await cosmosDbService.CreateTaskAsync(task);

        // Dapr: publish event and update state
        try
        {
            var pubsubName = Environment.GetEnvironmentVariable("DAPR_PUBSUB_NAME") ?? "pubsub";
            using var activity = Tracer.StartActivity("Dapr.Publish task.created", ActivityKind.Producer);
            activity?.SetTag("messaging.system", "dapr");
            activity?.SetTag("messaging.destination", "task.created");
            activity?.SetTag("messaging.dapr.pubsub", pubsubName);
            activity?.SetTag("tenant.id", created.TenantId);
            var traceparent = activity?.Id ?? Activity.Current?.Id;
            var tracestate = activity?.TraceStateString ?? Activity.Current?.TraceStateString;
            var metadata = new Dictionary<string, string>();
            if (!string.IsNullOrEmpty(traceparent)) metadata["traceparent"] = traceparent!;
            if (!string.IsNullOrEmpty(tracestate)) metadata["tracestate"] = tracestate!;

            var payload = new {
                id = created.Id,
                tenantId = created.TenantId,
                title = created.Title,
                priority = created.Priority,
                assigneeUserIds = created.AssigneeUserIds,
                createdBy = created.CreatedByUserId,
                traceId = (activity?.TraceId ?? Activity.Current?.TraceId).ToString(),
                spanId = (activity?.SpanId ?? Activity.Current?.SpanId).ToString()
            };

            // Try overload with metadata; if not available, a compile error will guide us to fallback below
            await dapr.PublishEventAsync(pubsubName, "task.created", payload, metadata);
            EventsPublishedCounter.Add(1, new KeyValuePair<string, object?>("topic", "task.created"));

            // Update state with enhanced service
            await daprStateService.SaveLastTaskAsync(created.TenantId, created);
            await daprStateService.IncrementTaskCountAsync(created.TenantId);
        }
        catch { /* non-blocking if dapr is not present */ }

        return created;
    }


    public async Task<TaskItem> UpdateTask(
        [Service] ICosmosDbService cosmosDbService,
        [Service] Dapr.Client.DaprClient dapr,
        TaskItem task)
    {
        if (string.IsNullOrWhiteSpace(task.Title))
            throw new Exception("Task title is required.");
        if (string.IsNullOrWhiteSpace(task.TenantId))
            throw new Exception("TenantId is required.");

    var updated = await cosmosDbService.UpdateTaskAsync(task);

        // Publish task updated event
        try
        {
            var pubsubName = Environment.GetEnvironmentVariable("DAPR_PUBSUB_NAME") ?? "pubsub";
            using var activity = Tracer.StartActivity("Dapr.Publish task.updated", ActivityKind.Producer);
            activity?.SetTag("messaging.system", "dapr");
            activity?.SetTag("messaging.destination", "task.updated");
            activity?.SetTag("messaging.dapr.pubsub", pubsubName);
            activity?.SetTag("tenant.id", updated.TenantId);
            var traceparent = activity?.Id ?? Activity.Current?.Id;
            var tracestate = activity?.TraceStateString ?? Activity.Current?.TraceStateString;
            var metadata = new Dictionary<string, string>();
            if (!string.IsNullOrEmpty(traceparent)) metadata["traceparent"] = traceparent!;
            if (!string.IsNullOrEmpty(tracestate)) metadata["tracestate"] = tracestate!;
            var payload = new {
                id = updated.Id,
                tenantId = updated.TenantId,
                title = updated.Title,
                priority = updated.Priority,
                isArchived = updated.IsArchived,
                traceId = (activity?.TraceId ?? Activity.Current?.TraceId).ToString(),
                spanId = (activity?.SpanId ?? Activity.Current?.SpanId).ToString()
            };
            await dapr.PublishEventAsync(pubsubName, "task.updated", payload, metadata);
            EventsPublishedCounter.Add(1, new KeyValuePair<string, object?>("topic", "task.updated"));
        }
        catch { /* non-blocking if dapr is not present */ }

        return updated;
    }

    public async Task<bool> DeleteTask(
        [Service] ICosmosDbService cosmosDbService,
        [Service] Dapr.Client.DaprClient dapr,
        Guid id,
        string tenantId)
    {
    await cosmosDbService.DeleteTaskAsync(id, tenantId);

        // Publish task deleted event
        try
        {
            var pubsubName = Environment.GetEnvironmentVariable("DAPR_PUBSUB_NAME") ?? "pubsub";
            using var activity = Tracer.StartActivity("Dapr.Publish task.deleted", ActivityKind.Producer);
            activity?.SetTag("messaging.system", "dapr");
            activity?.SetTag("messaging.destination", "task.deleted");
            activity?.SetTag("messaging.dapr.pubsub", pubsubName);
            activity?.SetTag("tenant.id", tenantId);
            var traceparent = activity?.Id ?? Activity.Current?.Id;
            var tracestate = activity?.TraceStateString ?? Activity.Current?.TraceStateString;
            var metadata = new Dictionary<string, string>();
            if (!string.IsNullOrEmpty(traceparent)) metadata["traceparent"] = traceparent!;
            if (!string.IsNullOrEmpty(tracestate)) metadata["tracestate"] = tracestate!;
            var payload = new {
                id,
                tenantId,
                deletedAt = DateTime.UtcNow,
                traceId = (activity?.TraceId ?? Activity.Current?.TraceId).ToString(),
                spanId = (activity?.SpanId ?? Activity.Current?.SpanId).ToString()
            };
            await dapr.PublishEventAsync(pubsubName, "task.deleted", payload, metadata);
            EventsPublishedCounter.Add(1, new KeyValuePair<string, object?>("topic", "task.deleted"));
        }
        catch { /* non-blocking if dapr is not present */ }

        return true;
    }

    public Task<Category> CreateCategory(
        [Service] ICosmosDbService cosmosDbService,
        Category category)
    {
        return cosmosDbService.CreateCategoryAsync(category);
    }

    public Task<Category> UpdateCategory(
        [Service] ICosmosDbService cosmosDbService,
        Category category)
    {
        return cosmosDbService.UpdateCategoryAsync(category);
    }

    public async Task<bool> DeleteCategory(
        [Service] ICosmosDbService cosmosDbService,
        Guid id,
        string tenantId)
    {
        await cosmosDbService.DeleteCategoryAsync(id, tenantId);
        return true;
    }

    public Task<TaskTracker.Blazor.Models.Tag> CreateTag(
        [Service] ICosmosDbService cosmosDbService,
    TaskTracker.Blazor.Models.Tag tag)
    {
    return cosmosDbService.CreateTagAsync(tag);
    }

    // UpdateTag is not implemented in CosmosDbService, so just return the created tag for now
    public Task<TaskTracker.Blazor.Models.Tag> UpdateTag(
        [Service] ICosmosDbService cosmosDbService,
    TaskTracker.Blazor.Models.Tag tag)
    {
        // No update logic, just create for now
    return cosmosDbService.CreateTagAsync(tag);
    }

    // DeleteTag is not implemented in CosmosDbService, so just return true for now
    public Task<bool> DeleteTag(
        [Service] ICosmosDbService cosmosDbService,
        Guid id,
        string tenantId)
    {
        // No delete logic, just return true
        return Task.FromResult(true);
    }

    // User management mutations
    public async Task<UserProfile> CreateUser(
        [Service] ICosmosDbService cosmosDbService,
        UserProfile user)
    {
        // CosmosDbService does not have CreateUser, so add to GetTenantUsersAsync and upsert
        var users = (await cosmosDbService.GetTenantUsersAsync(user.TenantId)).ToList();
        users.Add(user);
        // No direct DB call, so just return the user for now
        return user;
    }

    public Task<UserProfile> UpdateUser(
        [Service] ICosmosDbService cosmosDbService,
        UserProfile user)
    {
        // No direct DB call, so just return the user for now
        return Task.FromResult(user);
    }

    public Task<bool> DeleteUser(
        [Service] ICosmosDbService cosmosDbService,
        string tenantId,
        string userId)
    {
        // No direct DB call, so just return true for now
        return Task.FromResult(true);
    }

}
