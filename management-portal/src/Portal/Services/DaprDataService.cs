using Dapr.Client;
using System.Text.Json;
using System.Diagnostics;
using Stamps.ManagementPortal.Models;

namespace Stamps.ManagementPortal.Services;

/// <summary>
/// Dapr-enabled data service that provides distributed tracing, state management, and service-to-service communication
/// This service wraps the existing GraphQL data service with Dapr capabilities for enhanced debugging
/// </summary>
public class DaprDataService : IDataService
{
    private readonly DaprClient _daprClient;
    private readonly IDataService _innerDataService;
    private readonly ILogger<DaprDataService> _logger;
    private static readonly ActivitySource ActivitySource = new("DaprDataService");
    
    public DaprDataService(
        DaprClient daprClient, 
        GraphQLDataService innerDataService,
        ILogger<DaprDataService> logger)
    {
        _daprClient = daprClient;
        _innerDataService = innerDataService;
        _logger = logger;
    }

    public async Task<IReadOnlyList<Tenant>> GetTenantsAsync(CancellationToken ct = default)
    {
        using var activity = ActivitySource.StartActivity("DaprDataService.GetTenants");
        
        try
        {
            // Try to get from Dapr state store first (cache)
            var cachedTenants = await _daprClient.GetStateAsync<List<Tenant>>("cache-store", "tenants", cancellationToken: ct);
            if (cachedTenants != null && cachedTenants.Any())
            {
                _logger.LogInformation("Retrieved {Count} tenants from cache", cachedTenants.Count);
                activity?.SetTag("cache.hit", "true");
                return cachedTenants.AsReadOnly();
            }

            activity?.SetTag("cache.hit", "false");
            
            // Fallback to inner service
            _logger.LogInformation("Cache miss, falling back to inner service");
            var tenants = await _innerDataService.GetTenantsAsync(ct);

            // Cache the results if we have a list
            if (tenants is List<Tenant> tenantList && tenantList.Any())
            {
                await _daprClient.SaveStateAsync("cache-store", "tenants", tenantList, 
                    metadata: new Dictionary<string, string> { ["ttlInSeconds"] = "300" }, // 5 minute cache
                    cancellationToken: ct);
                _logger.LogInformation("Cached {Count} tenants", tenantList.Count);
            }

            return tenants;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving tenants via Dapr");
            activity?.SetTag("error", "true");
            activity?.SetTag("error.message", ex.Message);
            
            // Fallback to direct service call
            _logger.LogWarning("Falling back to direct service call");
            return await _innerDataService.GetTenantsAsync(ct);
        }
    }

    public async Task<IReadOnlyList<Cell>> GetCellsAsync(CancellationToken ct = default)
    {
        using var activity = ActivitySource.StartActivity("DaprDataService.GetCells");
        
        try
        {
            // Try cache first
            var cachedCells = await _daprClient.GetStateAsync<List<Cell>>("cache-store", "cells", cancellationToken: ct);
            if (cachedCells != null && cachedCells.Any())
            {
                _logger.LogInformation("Retrieved {Count} cells from cache", cachedCells.Count);
                activity?.SetTag("cache.hit", "true");
                return cachedCells.AsReadOnly();
            }

            activity?.SetTag("cache.hit", "false");
            
            // Fallback to inner service
            var cells = await _innerDataService.GetCellsAsync(ct);

            // Cache results if we have a list
            if (cells is List<Cell> cellList && cellList.Any())
            {
                await _daprClient.SaveStateAsync("cache-store", "cells", cellList,
                    metadata: new Dictionary<string, string> { ["ttlInSeconds"] = "300" },
                    cancellationToken: ct);
                _logger.LogInformation("Cached {Count} cells", cellList.Count);
            }

            return cells;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving cells via Dapr");
            activity?.SetTag("error", "true");
            activity?.SetTag("error.message", ex.Message);
            
            // Fallback to direct service call
            return await _innerDataService.GetCellsAsync(ct);
        }
    }

    public async Task<IReadOnlyList<Operation>> GetOperationsAsync(CancellationToken ct = default)
    {
        using var activity = ActivitySource.StartActivity("DaprDataService.GetOperations");
        
        try
        {
            // Try cache first
            var cachedOps = await _daprClient.GetStateAsync<List<Operation>>("cache-store", "operations", cancellationToken: ct);
            if (cachedOps != null && cachedOps.Any())
            {
                _logger.LogInformation("Retrieved {Count} operations from cache", cachedOps.Count);
                activity?.SetTag("cache.hit", "true");
                return cachedOps.AsReadOnly();
            }

            activity?.SetTag("cache.hit", "false");
            
            // Fallback to inner service
            var operations = await _innerDataService.GetOperationsAsync(ct);

            // Cache results if we have a list
            if (operations is List<Operation> opList && opList.Any())
            {
                await _daprClient.SaveStateAsync("cache-store", "operations", opList,
                    metadata: new Dictionary<string, string> { ["ttlInSeconds"] = "180" }, // 3 minute cache
                    cancellationToken: ct);
                _logger.LogInformation("Cached {Count} operations", opList.Count);
            }

            return operations;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving operations via Dapr");
            activity?.SetTag("error", "true");
            activity?.SetTag("error.message", ex.Message);
            
            // Fallback to direct service call
            return await _innerDataService.GetOperationsAsync(ct);
        }
    }

    // CRUD Operations - Pass through to inner service with tracing
    public async Task<Tenant> CreateTenantAsync(Tenant tenant, CancellationToken ct = default)
    {
        using var activity = ActivitySource.StartActivity("DaprDataService.CreateTenant");
        activity?.SetTag("tenant.id", tenant.Id);
        
        try
        {
            var result = await _innerDataService.CreateTenantAsync(tenant, ct);
            // Invalidate cache after creation
            await InvalidateCacheAsync("tenants", ct);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating tenant {TenantId}", tenant.Id);
            activity?.SetTag("error", "true");
            throw;
        }
    }

    public async Task<Tenant> UpdateTenantAsync(Tenant tenant, CancellationToken ct = default)
    {
        using var activity = ActivitySource.StartActivity("DaprDataService.UpdateTenant");
        activity?.SetTag("tenant.id", tenant.Id);
        
        try
        {
            var result = await _innerDataService.UpdateTenantAsync(tenant, ct);
            // Invalidate cache after update
            await InvalidateCacheAsync("tenants", ct);
            await InvalidateCacheAsync($"tenant-{tenant.Id}", ct);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating tenant {TenantId}", tenant.Id);
            activity?.SetTag("error", "true");
            throw;
        }
    }

    public async Task DeleteTenantAsync(string id, string partitionKey, CancellationToken ct = default)
    {
        using var activity = ActivitySource.StartActivity("DaprDataService.DeleteTenant");
        activity?.SetTag("tenant.id", id);
        
        try
        {
            await _innerDataService.DeleteTenantAsync(id, partitionKey, ct);
            // Invalidate cache after deletion
            await InvalidateCacheAsync("tenants", ct);
            await InvalidateCacheAsync($"tenant-{id}", ct);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting tenant {TenantId}", id);
            activity?.SetTag("error", "true");
            throw;
        }
    }

    public async Task<Cell> CreateCellAsync(Cell cell, CancellationToken ct = default)
    {
        using var activity = ActivitySource.StartActivity("DaprDataService.CreateCell");
        activity?.SetTag("cell.id", cell.Id);
        
        try
        {
            var result = await _innerDataService.CreateCellAsync(cell, ct);
            await InvalidateCacheAsync("cells", ct);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating cell {CellId}", cell.Id);
            activity?.SetTag("error", "true");
            throw;
        }
    }

    public async Task<Cell> UpdateCellAsync(Cell cell, CancellationToken ct = default)
    {
        using var activity = ActivitySource.StartActivity("DaprDataService.UpdateCell");
        activity?.SetTag("cell.id", cell.Id);
        
        try
        {
            var result = await _innerDataService.UpdateCellAsync(cell, ct);
            await InvalidateCacheAsync("cells", ct);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating cell {CellId}", cell.Id);
            activity?.SetTag("error", "true");
            throw;
        }
    }

    public async Task DeleteCellAsync(string id, string partitionKey, CancellationToken ct = default)
    {
        using var activity = ActivitySource.StartActivity("DaprDataService.DeleteCell");
        activity?.SetTag("cell.id", id);
        
        try
        {
            await _innerDataService.DeleteCellAsync(id, partitionKey, ct);
            await InvalidateCacheAsync("cells", ct);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting cell {CellId}", id);
            activity?.SetTag("error", "true");
            throw;
        }
    }

    public async Task<Operation> CreateOperationAsync(Operation op, CancellationToken ct = default)
    {
        using var activity = ActivitySource.StartActivity("DaprDataService.CreateOperation");
        activity?.SetTag("operation.id", op.Id);
        
        try
        {
            var result = await _innerDataService.CreateOperationAsync(op, ct);
            await InvalidateCacheAsync("operations", ct);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating operation {OperationId}", op.Id);
            activity?.SetTag("error", "true");
            throw;
        }
    }

    public async Task<Operation> UpdateOperationAsync(Operation op, CancellationToken ct = default)
    {
        using var activity = ActivitySource.StartActivity("DaprDataService.UpdateOperation");
        activity?.SetTag("operation.id", op.Id);
        
        try
        {
            var result = await _innerDataService.UpdateOperationAsync(op, ct);
            await InvalidateCacheAsync("operations", ct);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating operation {OperationId}", op.Id);
            activity?.SetTag("error", "true");
            throw;
        }
    }

    public async Task DeleteOperationAsync(string id, string partitionKey, CancellationToken ct = default)
    {
        using var activity = ActivitySource.StartActivity("DaprDataService.DeleteOperation");
        activity?.SetTag("operation.id", id);
        
        try
        {
            await _innerDataService.DeleteOperationAsync(id, partitionKey, ct);
            await InvalidateCacheAsync("operations", ct);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting operation {OperationId}", id);
            activity?.SetTag("error", "true");
            throw;
        }
    }

    public async Task<bool> ReserveDomainAsync(string domain, string ownerTenantId, CancellationToken ct = default)
    {
        using var activity = ActivitySource.StartActivity("DaprDataService.ReserveDomain");
        activity?.SetTag("domain", domain);
        activity?.SetTag("owner.tenant.id", ownerTenantId);
        
        try
        {
            return await _innerDataService.ReserveDomainAsync(domain, ownerTenantId, ct);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error reserving domain {Domain} for tenant {TenantId}", domain, ownerTenantId);
            activity?.SetTag("error", "true");
            throw;
        }
    }

    public async Task ReleaseDomainAsync(string domain, CancellationToken ct = default)
    {
        using var activity = ActivitySource.StartActivity("DaprDataService.ReleaseDomain");
        activity?.SetTag("domain", domain);
        
        try
        {
            await _innerDataService.ReleaseDomainAsync(domain, ct);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error releasing domain {Domain}", domain);
            activity?.SetTag("error", "true");
            throw;
        }
    }

    // Helper method to invalidate cache entries
    private async Task InvalidateCacheAsync(string key, CancellationToken ct = default)
    {
        try
        {
            await _daprClient.DeleteStateAsync("cache-store", key, cancellationToken: ct);
            _logger.LogDebug("Invalidated cache key: {Key}", key);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to invalidate cache key: {Key}", key);
            // Don't throw - cache invalidation failure shouldn't break the operation
        }
    }

    // Health check method to verify Dapr connectivity
    public async Task<bool> CheckDaprHealthAsync()
    {
        try
        {
            // Simple health check - try to get Dapr metadata
            await _daprClient.GetMetadataAsync();
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Dapr health check failed");
            return false;
        }
    }
}
