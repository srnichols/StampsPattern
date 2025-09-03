using Dapr.Client;
using TaskTracker.Blazor.Models;

namespace TaskTracker.Blazor.Services;

public interface IDaprStateService
{
    Task SaveLastTaskAsync(string tenantId, TaskItem task);
    Task<LastTaskInfo?> GetLastTaskAsync(string tenantId);
    Task SaveTenantStatsAsync(string tenantId, TenantStats stats);
    Task<TenantStats?> GetTenantStatsAsync(string tenantId);
    Task IncrementTaskCountAsync(string tenantId);
}

public class DaprStateService : IDaprStateService
{
    private readonly DaprClient _daprClient;
    private readonly string _stateStoreName;
    private readonly ILogger<DaprStateService> _logger;

    public DaprStateService(DaprClient daprClient, ILogger<DaprStateService> logger)
    {
        _daprClient = daprClient;
        _stateStoreName = Environment.GetEnvironmentVariable("DAPR_STATESTORE_NAME") ?? "statestore";
        _logger = logger;
    }

    public async Task SaveLastTaskAsync(string tenantId, TaskItem task)
    {
        try
        {
            var lastTaskInfo = new LastTaskInfo
            {
                Id = task.Id,
                Title = task.Title,
                TenantId = task.TenantId,
                Priority = task.Priority,
                CreatedAt = DateTime.UtcNow
            };

            await _daprClient.SaveStateAsync(_stateStoreName, $"task:last:{tenantId}", lastTaskInfo);
            _logger.LogDebug("Saved last task info for tenant {TenantId}: {TaskId}", tenantId, task.Id);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to save last task info for tenant {TenantId}", tenantId);
        }
    }

    public async Task<LastTaskInfo?> GetLastTaskAsync(string tenantId)
    {
        try
        {
            return await _daprClient.GetStateAsync<LastTaskInfo>(_stateStoreName, $"task:last:{tenantId}");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to get last task info for tenant {TenantId}", tenantId);
            return null;
        }
    }

    public async Task SaveTenantStatsAsync(string tenantId, TenantStats stats)
    {
        try
        {
            await _daprClient.SaveStateAsync(_stateStoreName, $"stats:{tenantId}", stats);
            _logger.LogDebug("Saved tenant stats for {TenantId}", tenantId);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to save tenant stats for {TenantId}", tenantId);
        }
    }

    public async Task<TenantStats?> GetTenantStatsAsync(string tenantId)
    {
        try
        {
            return await _daprClient.GetStateAsync<TenantStats>(_stateStoreName, $"stats:{tenantId}");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to get tenant stats for {TenantId}", tenantId);
            return null;
        }
    }

    public async Task IncrementTaskCountAsync(string tenantId)
    {
        try
        {
            var stats = await GetTenantStatsAsync(tenantId) ?? new TenantStats { TenantId = tenantId };
            stats.TotalTasks++;
            stats.LastUpdated = DateTime.UtcNow;
            await SaveTenantStatsAsync(tenantId, stats);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to increment task count for tenant {TenantId}", tenantId);
        }
    }
}

// Data models for state
public record LastTaskInfo
{
    public Guid Id { get; init; }
    public string Title { get; init; } = string.Empty;
    public string TenantId { get; init; } = string.Empty;
    public Priority Priority { get; init; }
    public DateTime CreatedAt { get; init; }
}

public record TenantStats
{
    public string TenantId { get; init; } = string.Empty;
    public int TotalTasks { get; set; }
    public int CompletedTasks { get; set; }
    public int ActiveUsers { get; set; }
    public DateTime LastUpdated { get; set; }
}
