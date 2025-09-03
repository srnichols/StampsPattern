using Microsoft.AspNetCore.Mvc;
using Dapr;
using TaskTracker.Blazor.Services;
using TaskTracker.Blazor.Models;
using System.Diagnostics;
using System.Collections.Generic;

namespace TaskTracker.Blazor.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DaprController : ControllerBase
{
    private readonly ILogger<DaprController> _logger;
    private readonly ICosmosDbService _cosmosDbService;
    private readonly IDaprStateService _daprStateService;

    public DaprController(ILogger<DaprController> logger, ICosmosDbService cosmosDbService, IDaprStateService daprStateService)
    {
        _logger = logger;
        _cosmosDbService = cosmosDbService;
        _daprStateService = daprStateService;
    }

    /// <summary>
    /// Handle task.created events - could be used for analytics, notifications, etc.
    /// </summary>
    [Dapr.Topic("pubsub", "task.created")]
    [HttpPost("task-created")]
    public async Task<IActionResult> HandleTaskCreated([FromBody] TaskCreatedEvent taskEvent)
    {
        // Extract W3C context from headers if present (Dapr forwards metadata as headers like traceparent/tracestate)
        var traceparent = Request.Headers["traceparent"].ToString();
        var tracestate = Request.Headers["tracestate"].ToString();
        ActivityContext parentContext = default;
        if (!string.IsNullOrEmpty(traceparent))
        {
            ActivityContext.TryParse(traceparent, tracestate, out parentContext);
        }

        using var activity = new Activity("Dapr.Consume task.created").SetParentId(parentContext.TraceId, parentContext.SpanId, parentContext.TraceFlags);
        if (parentContext != default) activity.SetParentId(traceparent);
        activity.Start();
        activity?.SetTag("messaging.system", "dapr");
        activity?.SetTag("messaging.operation", "receive");
        activity?.SetTag("messaging.destination", "task.created");
        activity?.SetTag("tenant.id", taskEvent.TenantId);

        _logger.LogInformation("Task created event received: {TaskId} for tenant {TenantId}",
            taskEvent.Id, taskEvent.TenantId);

        try
        {
            // Update state management - increment task count
            await _daprStateService.IncrementTaskCountAsync(taskEvent.TenantId);
            
            // Create a minimal TaskItem for state storage
            var taskItem = new TaskItem
            {
                Id = taskEvent.Id,
                Title = taskEvent.Title,
                TenantId = taskEvent.TenantId,
                CreatedAtUtc = DateTime.UtcNow,
                UpdatedAtUtc = DateTime.UtcNow,
                Priority = Priority.Mid,
                CreatedByUserId = "system" // Default for events
            };
            
            await _daprStateService.SaveLastTaskAsync(taskEvent.TenantId, taskItem);
            
            _logger.LogInformation("Updated Dapr state for tenant {TenantId}", taskEvent.TenantId);
            
            return Ok();
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Error handling task created event for task {TaskId}", taskEvent.Id);
            return StatusCode(500);
        }
        finally
        {
            activity?.Stop();
        }
    }

    /// <summary>
    /// Test endpoint to get tenant statistics from Dapr state
    /// </summary>
    [HttpGet("tenant/{tenantId}/stats")]
    public async Task<IActionResult> GetTenantStats(string tenantId)
    {
        try
        {
            var stats = await _daprStateService.GetTenantStatsAsync(tenantId);
            return Ok(stats);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting tenant stats for {TenantId}", tenantId);
            return StatusCode(500);
        }
    }

    /// <summary>
    /// Handle dapr health checks
    /// </summary>
    [HttpGet("health")]
    public IActionResult Health()
    {
        return Ok(new { status = "healthy", timestamp = DateTime.UtcNow });
    }
}

/// <summary>
/// Event payload for task.created events
/// </summary>
public record TaskCreatedEvent(Guid Id, string TenantId, string Title);
