using System;
using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Cosmos;
using System.Text.Json;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;
using Microsoft.Extensions.Logging;
using AzureStampsPattern.Models;

public class CreateTenantFunction
{
    private readonly CosmosClient _cosmosClient;
    private readonly Container _tenantsContainer;
    private readonly Container _cellsContainer;
    private readonly ILogger<CreateTenantFunction> _logger;

    // Use dependency injection for better testability
    public CreateTenantFunction(CosmosClient cosmosClient, ILogger<CreateTenantFunction> logger)
    {
        _cosmosClient = cosmosClient ?? throw new ArgumentNullException(nameof(cosmosClient));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        
        string databaseName = Environment.GetEnvironmentVariable("CosmosDbDatabaseName") ?? "globaldb";
        string tenantsContainerName = Environment.GetEnvironmentVariable("TenantsContainerName") ?? "tenants";
        string cellsContainerName = Environment.GetEnvironmentVariable("CellsContainerName") ?? "cells";
        
        _tenantsContainer = _cosmosClient.GetContainer(databaseName, tenantsContainerName);
        _cellsContainer = _cosmosClient.GetContainer(databaseName, cellsContainerName);
    }

    // Fallback constructor for environments without DI
    public CreateTenantFunction() : this(
        new CosmosClient(Environment.GetEnvironmentVariable("CosmosDbConnection") ?? 
            throw new InvalidOperationException("CosmosDbConnection not configured")),
        LoggerFactory.Create(builder => builder.AddConsole()).CreateLogger<CreateTenantFunction>())
    {
    }

    [Function("CreateTenant")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "tenant")] HttpRequestData req)
    {
        try
        {
            _logger.LogInformation("Creating new tenant...");
            
            var tenant = await req.ReadFromJsonAsync<TenantInfo>();

            // Validate tenant requirements
            if (string.IsNullOrEmpty(tenant?.tenantId) || string.IsNullOrEmpty(tenant.subdomain))
            {
                _logger.LogWarning("Invalid tenant data: missing tenantId or subdomain");
                var errorResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                await errorResponse.WriteStringAsync("TenantId and Subdomain are required.");
                return errorResponse;
            }

            // Set default values if not provided
            tenant.tenantTier = tenant.tenantTier ?? TenantTier.Shared;
            tenant.region = tenant.region ?? "eastus";
            tenant.complianceRequirements = tenant.complianceRequirements ?? new List<string>();
            tenant.createdDate = DateTime.UtcNow;
            tenant.status = TenantStatus.Active;

            _logger.LogInformation("Assigning CELL for tenant {TenantId} in region {Region}", tenant.tenantId, tenant.region);

            // Assign CELL based on intelligent logic
            var assignmentResult = await AssignCellForTenantAsync(tenant);
            
            if (!assignmentResult.Success)
            {
                _logger.LogError("CELL assignment failed for tenant {TenantId}: {Error}", tenant.tenantId, assignmentResult.ErrorMessage);
                var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
                await errorResponse.WriteStringAsync($"Failed to assign CELL: {assignmentResult.ErrorMessage}");
                return errorResponse;
            }

            tenant.cellBackendPool = assignmentResult.CellBackendPool;
            tenant.cellName = assignmentResult.CellName;

            // Create tenant in database
            await _tenantsContainer.CreateItemAsync(tenant, new PartitionKey(tenant.tenantId));
            
            _logger.LogInformation("Successfully created tenant {TenantId} in CELL {CellName}", tenant.tenantId, tenant.cellName);

            var response = req.CreateResponse(HttpStatusCode.Created);
            await response.WriteAsJsonAsync(tenant);
            return response;
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Invalid JSON in request body");
            var errorResponse = req.CreateResponse(HttpStatusCode.BadRequest);
            await errorResponse.WriteStringAsync("Invalid JSON format in request body.");
            return errorResponse;
        }
        catch (CosmosException ex)
        {
            _logger.LogError(ex, "Cosmos DB error during tenant creation");
            var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
            await errorResponse.WriteStringAsync("Database error occurred. Please try again.");
            return errorResponse;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error during tenant creation");
            var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
            await errorResponse.WriteStringAsync("An unexpected error occurred. Please contact support.");
            return errorResponse;
        }
    }

    /// <summary>
    /// Intelligent CELL assignment logic supporting flexible tenancy models
    /// </summary>
    private async Task<CellAssignmentResult> AssignCellForTenantAsync(TenantInfo tenant)
    {
        try
        {
            _logger.LogInformation("Getting available CELLs for region {Region}", tenant.region);
            
            // Get available CELLs for the region
            var availableCells = await GetAvailableCellsInRegionAsync(tenant.region);

            if (!availableCells.Any())
            {
                _logger.LogWarning("No available CELLs found in region {Region}", tenant.region);
                return new CellAssignmentResult 
                { 
                    Success = false, 
                    ErrorMessage = $"No available CELLs found in region {tenant.region}" 
                };
            }

            CellInfo selectedCell = null;

            switch (tenant.tenantTier)
            {
                case TenantTier.Enterprise:
                case TenantTier.Dedicated:
                    _logger.LogInformation("Assigning dedicated CELL for enterprise tenant {TenantId}", tenant.tenantId);
                    selectedCell = await AssignDedicatedCellAsync(tenant, availableCells);
                    break;

                case TenantTier.Shared:
                case TenantTier.Startup:
                case TenantTier.SMB:
                    _logger.LogInformation("Assigning shared CELL for tenant {TenantId}", tenant.tenantId);
                    selectedCell = await AssignSharedCellAsync(tenant, availableCells);
                    break;

                default:
                    _logger.LogInformation("Using default shared CELL assignment for tenant {TenantId}", tenant.tenantId);
                    selectedCell = await AssignSharedCellAsync(tenant, availableCells);
                    break;
            }

            if (selectedCell == null)
            {
                _logger.LogError("Unable to find suitable CELL for tenant {TenantId} with tier {TenantTier}", tenant.tenantId, tenant.tenantTier);
                return new CellAssignmentResult 
                { 
                    Success = false, 
                    ErrorMessage = "Unable to find suitable CELL for tenant requirements" 
                };
            }

            // Update CELL tenant count
            await UpdateCellTenantCountAsync(selectedCell.cellId, 1);
            
            _logger.LogInformation("Successfully assigned CELL {CellName} to tenant {TenantId}", selectedCell.cellName, tenant.tenantId);

            return new CellAssignmentResult
            {
                Success = true,
                CellBackendPool = selectedCell.backendPool,
                CellName = selectedCell.cellName
            };
        }
        catch (CosmosException ex)
        {
            _logger.LogError(ex, "Cosmos DB error during CELL assignment for tenant {TenantId}", tenant.tenantId);
            return new CellAssignmentResult 
            { 
                Success = false, 
                ErrorMessage = $"Database error during CELL assignment: {ex.Message}" 
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error during CELL assignment for tenant {TenantId}", tenant.tenantId);
            return new CellAssignmentResult 
            { 
                Success = false, 
                ErrorMessage = $"Error during CELL assignment: {ex.Message}" 
            };
        }
    }

    /// <summary>
    /// Assign a dedicated CELL for enterprise tenants
    /// </summary>
    private async Task<CellInfo> AssignDedicatedCellAsync(TenantInfo tenant, List<CellInfo> availableCells)
    {
        // Find empty CELLs or create new dedicated CELL
        var emptyCells = availableCells.Where(c => 
            c.cellType == CellType.Dedicated && 
            c.currentTenantCount == 0 &&
            MeetsComplianceRequirements(c, tenant.complianceRequirements)).ToList();

        if (emptyCells.Any())
        {
            // Prefer CELLs that match tenant's compliance requirements
            var perfectMatch = emptyCells.FirstOrDefault(c => 
                c.complianceFeatures.Intersect(tenant.complianceRequirements).Count() == tenant.complianceRequirements.Count);
            
            return perfectMatch ?? emptyCells.First();
        }

        // If no empty dedicated CELLs, check if we can provision a new one
        if (availableCells.Count(c => c.cellType == CellType.Dedicated) < GetMaxCellsPerRegion())
        {
            return await ProvisionNewDedicatedCellAsync(tenant);
        }

        return null; // No available dedicated CELLs
    }

    /// <summary>
    /// Assign a shared CELL for smaller tenants
    /// </summary>
    private async Task<CellInfo> AssignSharedCellAsync(TenantInfo tenant, List<CellInfo> availableCells)
    {
        // Find shared CELLs with available capacity
        var sharedCells = availableCells.Where(c => 
            c.cellType == CellType.Shared && 
            c.currentTenantCount < c.maxTenantCount &&
            MeetsComplianceRequirements(c, tenant.complianceRequirements)).ToList();

        if (sharedCells.Any())
        {
            // Select CELL with lowest tenant count for load balancing
            return sharedCells.OrderBy(c => c.currentTenantCount).First();
        }

        // If no shared CELLs have capacity, provision a new shared CELL
        if (availableCells.Count(c => c.cellType == CellType.Shared) < GetMaxCellsPerRegion())
        {
            return await ProvisionNewSharedCellAsync(tenant);
        }

        return null; // No available capacity
    }

    /// <summary>
    /// Check if CELL meets tenant's compliance requirements
    /// </summary>
    private bool MeetsComplianceRequirements(CellInfo cell, List<string> requirements)
    {
        if (requirements == null || !requirements.Any())
            return true;

        return requirements.All(req => cell.complianceFeatures.Contains(req));
    }

    /// <summary>
    /// Get available CELLs in a specific region
    /// </summary>
    private async Task<List<CellInfo>> GetAvailableCellsInRegionAsync(string region)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.region = @region AND c.status = @status")
            .WithParameter("@region", region)
            .WithParameter("@status", CellStatus.Active.ToString());

        var cells = new List<CellInfo>();
        var iterator = _cellsContainer.GetItemQueryIterator<CellInfo>(query);

        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            cells.AddRange(response);
        }

        return cells;
    }

    /// <summary>
    /// Update tenant count for a CELL
    /// </summary>
    private async Task UpdateCellTenantCountAsync(string cellId, int increment)
    {
        try
        {
            var cell = await _cellsContainer.ReadItemAsync<CellInfo>(cellId, new PartitionKey(cellId));
            cell.Resource.currentTenantCount += increment;
            await _cellsContainer.ReplaceItemAsync(cell.Resource, cellId, new PartitionKey(cellId));
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            // CELL not found - this might be a newly provisioned CELL
            // Log warning but don't fail the operation
        }
    }

    /// <summary>
    /// Provision a new dedicated CELL for enterprise tenant
    /// </summary>
    private async Task<CellInfo> ProvisionNewDedicatedCellAsync(TenantInfo tenant)
    {
        var cellName = $"dedicated-{tenant.tenantId}-{tenant.region}";
        var newCell = new CellInfo
        {
            cellId = Guid.NewGuid().ToString(),
            cellName = cellName,
            cellType = CellType.Dedicated,
            region = tenant.region,
            backendPool = $"{cellName}-backend",
            maxTenantCount = 1,
            currentTenantCount = 0,
            status = CellStatus.Provisioning,
            complianceFeatures = tenant.complianceRequirements ?? new List<string>(),
            createdDate = DateTime.UtcNow
        };

        await _cellsContainer.CreateItemAsync(newCell, new PartitionKey(newCell.cellId));
        
        // TODO: Trigger actual Azure resource provisioning
        // This would call Azure Resource Manager APIs or trigger deployment pipeline
        
        return newCell;
    }

    /// <summary>
    /// Provision a new shared CELL
    /// </summary>
    private async Task<CellInfo> ProvisionNewSharedCellAsync(TenantInfo tenant)
    {
        var cellName = $"shared-{tenant.region}-{Guid.NewGuid().ToString("N")[..8]}";
        var newCell = new CellInfo
        {
            cellId = Guid.NewGuid().ToString(),
            cellName = cellName,
            cellType = CellType.Shared,
            region = tenant.region,
            backendPool = $"{cellName}-backend",
            maxTenantCount = GetMaxTenantsPerSharedCell(),
            currentTenantCount = 0,
            status = CellStatus.Provisioning,
            complianceFeatures = new List<string>(),
            createdDate = DateTime.UtcNow
        };

        await _cellsContainer.CreateItemAsync(newCell, new PartitionKey(newCell.cellId));
        
        // TODO: Trigger actual Azure resource provisioning
        
        return newCell;
    }

    /// <summary>
    /// Get maximum number of CELLs allowed per region
    /// </summary>
    private int GetMaxCellsPerRegion()
    {
        return int.Parse(Environment.GetEnvironmentVariable("MaxCellsPerRegion") ?? "20");
    }

    /// <summary>
    /// Get maximum number of tenants allowed per shared CELL
    /// </summary>
    private int GetMaxTenantsPerSharedCell()
    {
        return int.Parse(Environment.GetEnvironmentVariable("MaxTenantsPerSharedCell") ?? "100");
    }
}