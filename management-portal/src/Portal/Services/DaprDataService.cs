using Dapr.Client;
using System.Text.Json;
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
    
    public DaprDataService(
        DaprClient daprClient, 
        GraphQLDataService innerDataService,
        ILogger<DaprDataService> logger)
    {
        _daprClient = daprClient;
        _innerDataService = innerDataService;
        _logger = logger;
    }

    public async Task<List<Tenant>> GetTenantsAsync()
    {
        using var activity = System.Diagnostics.Activity.StartActivity("DaprDataService.GetTenants");
        
        try
        {
            // Try to get from Dapr state store first (cache)
            var cachedTenants = await _daprClient.GetStateAsync<List<Tenant>>("cache-store", "tenants");
            if (cachedTenants != null && cachedTenants.Any())
            {
                _logger.LogInformation("Retrieved {Count} tenants from cache", cachedTenants.Count);
                activity?.SetTag("cache.hit", "true");
                return cachedTenants;
            }

            activity?.SetTag("cache.hit", "false");
            
            // Fallback to GraphQL service via Dapr service invocation
            _logger.LogInformation("Cache miss, invoking DAB service via Dapr");
            
            var tenants = await _daprClient.InvokeMethodAsync<List<Tenant>>(
                "dab", 
                "tenants",
                new HttpInvocationOptions
                {
                    Timeout = TimeSpan.FromSeconds(30)
                });

            // Cache the results
            if (tenants?.Any() == true)
            {
                await _daprClient.SaveStateAsync("cache-store", "tenants", tenants, 
                    metadata: new Dictionary<string, string> { ["ttlInSeconds"] = "300" }); // 5 minute cache
                _logger.LogInformation("Cached {Count} tenants", tenants.Count);
            }

            return tenants ?? new List<Tenant>();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving tenants via Dapr");
            activity?.SetTag("error", "true");
            activity?.SetTag("error.message", ex.Message);
            
            // Fallback to direct service call
            _logger.LogWarning("Falling back to direct GraphQL service call");
            return await _innerDataService.GetTenantsAsync();
        }
    }

    public async Task<List<Cell>> GetCellsAsync()
    {
        using var activity = System.Diagnostics.Activity.StartActivity("DaprDataService.GetCells");
        
        try
        {
            // Try cache first
            var cachedCells = await _daprClient.GetStateAsync<List<Cell>>("cache-store", "cells");
            if (cachedCells != null && cachedCells.Any())
            {
                _logger.LogInformation("Retrieved {Count} cells from cache", cachedCells.Count);
                activity?.SetTag("cache.hit", "true");
                return cachedCells;
            }

            activity?.SetTag("cache.hit", "false");
            
            // Service invocation via Dapr
            var cells = await _daprClient.InvokeMethodAsync<List<Cell>>(
                "dab", 
                "cells",
                new HttpInvocationOptions
                {
                    Timeout = TimeSpan.FromSeconds(30)
                });

            // Cache results
            if (cells?.Any() == true)
            {
                await _daprClient.SaveStateAsync("cache-store", "cells", cells,
                    metadata: new Dictionary<string, string> { ["ttlInSeconds"] = "300" });
                _logger.LogInformation("Cached {Count} cells", cells.Count);
            }

            return cells ?? new List<Cell>();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving cells via Dapr");
            activity?.SetTag("error", "true");
            activity?.SetTag("error.message", ex.Message);
            
            // Fallback to direct service call
            return await _innerDataService.GetCellsAsync();
        }
    }

    public async Task<List<Operation>> GetOperationsAsync()
    {
        using var activity = System.Diagnostics.Activity.StartActivity("DaprDataService.GetOperations");
        
        try
        {
            // Try cache first
            var cachedOps = await _daprClient.GetStateAsync<List<Operation>>("cache-store", "operations");
            if (cachedOps != null && cachedOps.Any())
            {
                _logger.LogInformation("Retrieved {Count} operations from cache", cachedOps.Count);
                activity?.SetTag("cache.hit", "true");
                return cachedOps;
            }

            activity?.SetTag("cache.hit", "false");
            
            // Service invocation via Dapr
            var operations = await _daprClient.InvokeMethodAsync<List<Operation>>(
                "dab", 
                "operations",
                new HttpInvocationOptions
                {
                    Timeout = TimeSpan.FromSeconds(30)
                });

            // Cache results
            if (operations?.Any() == true)
            {
                await _daprClient.SaveStateAsync("cache-store", "operations", operations,
                    metadata: new Dictionary<string, string> { ["ttlInSeconds"] = "180" }); // 3 minute cache
                _logger.LogInformation("Cached {Count} operations", operations.Count);
            }

            return operations ?? new List<Operation>();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving operations via Dapr");
            activity?.SetTag("error", "true");
            activity?.SetTag("error.message", ex.Message);
            
            // Fallback to direct service call
            return await _innerDataService.GetOperationsAsync();
        }
    }

    public async Task<Tenant?> GetTenantAsync(string id)
    {
        using var activity = System.Diagnostics.Activity.StartActivity("DaprDataService.GetTenant");
        activity?.SetTag("tenant.id", id);
        
        try
        {
            // Try cache first
            var cacheKey = $"tenant-{id}";
            var cachedTenant = await _daprClient.GetStateAsync<Tenant>("cache-store", cacheKey);
            if (cachedTenant != null)
            {
                _logger.LogInformation("Retrieved tenant {TenantId} from cache", id);
                activity?.SetTag("cache.hit", "true");
                return cachedTenant;
            }

            activity?.SetTag("cache.hit", "false");
            
            // Service invocation via Dapr
            var tenant = await _daprClient.InvokeMethodAsync<Tenant>(
                "dab", 
                $"tenants/{id}",
                new HttpInvocationOptions
                {
                    Timeout = TimeSpan.FromSeconds(30)
                });

            // Cache result
            if (tenant != null)
            {
                await _daprClient.SaveStateAsync("cache-store", cacheKey, tenant,
                    metadata: new Dictionary<string, string> { ["ttlInSeconds"] = "600" }); // 10 minute cache
                _logger.LogInformation("Cached tenant {TenantId}", id);
            }

            return tenant;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving tenant {TenantId} via Dapr", id);
            activity?.SetTag("error", "true");
            activity?.SetTag("error.message", ex.Message);
            
            // Fallback to direct service call
            return await _innerDataService.GetTenantAsync(id);
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
