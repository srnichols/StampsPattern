using System;
using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Cosmos;
using System.Text.Json;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;

public class CreateTenantFunction
{
    private readonly CosmosClient _cosmosClient;
    private readonly Container _tenantsContainer;
    private readonly Container _cellsContainer;

    public CreateTenantFunction()
    {
        string cosmosDbConnectionString = Environment.GetEnvironmentVariable("CosmosDbConnection");
        string databaseName = Environment.GetEnvironmentVariable("CosmosDbDatabaseName") ?? "globaldb";
        string tenantsContainerName = Environment.GetEnvironmentVariable("TenantsContainerName") ?? "tenants";
        string cellsContainerName = Environment.GetEnvironmentVariable("CellsContainerName") ?? "cells";
        
        _cosmosClient = new CosmosClient(cosmosDbConnectionString);
        _tenantsContainer = _cosmosClient.GetContainer(databaseName, tenantsContainerName);
        _cellsContainer = _cosmosClient.GetContainer(databaseName, cellsContainerName);
    }

    [Function("CreateTenant")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "tenant")] HttpRequestData req)
    {
        var tenant = await req.ReadFromJsonAsync<TenantInfo>();

        // Validate tenant requirements
        if (string.IsNullOrEmpty(tenant.tenantId) || string.IsNullOrEmpty(tenant.subdomain))
        {
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

        // Assign CELL based on intelligent logic
        var assignmentResult = await AssignCellForTenantAsync(tenant);
        
        if (!assignmentResult.Success)
        {
            var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
            await errorResponse.WriteStringAsync($"Failed to assign CELL: {assignmentResult.ErrorMessage}");
            return errorResponse;
        }

        tenant.cellBackendPool = assignmentResult.CellBackendPool;
        tenant.cellName = assignmentResult.CellName;

        // Create tenant in database
        await _tenantsContainer.CreateItemAsync(tenant, new PartitionKey(tenant.tenantId));

        var response = req.CreateResponse(HttpStatusCode.Created);
        await response.WriteAsJsonAsync(tenant);
        return response;
    }

    /// <summary>
    /// Intelligent CELL assignment logic supporting flexible tenancy models
    /// </summary>
    private async Task<CellAssignmentResult> AssignCellForTenantAsync(TenantInfo tenant)
    {
        try
        {
            // Get available CELLs for the region
            var availableCells = await GetAvailableCellsInRegionAsync(tenant.region);

            if (!availableCells.Any())
            {
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
                    selectedCell = await AssignDedicatedCellAsync(tenant, availableCells);
                    break;

                case TenantTier.Shared:
                case TenantTier.Startup:
                case TenantTier.SMB:
                    selectedCell = await AssignSharedCellAsync(tenant, availableCells);
                    break;

                default:
                    selectedCell = await AssignSharedCellAsync(tenant, availableCells);
                    break;
            }

            if (selectedCell == null)
            {
                return new CellAssignmentResult 
                { 
                    Success = false, 
                    ErrorMessage = "Unable to find suitable CELL for tenant requirements" 
                };
            }

            // Update CELL tenant count
            await UpdateCellTenantCountAsync(selectedCell.cellId, 1);

            return new CellAssignmentResult
            {
                Success = true,
                CellBackendPool = selectedCell.backendPool,
                CellName = selectedCell.cellName
            };
        }
        catch (Exception ex)
        {
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

/// <summary>
/// Enhanced tenant information supporting flexible tenancy models
/// </summary>
public class TenantInfo
{
    public string tenantId { get; set; }
    public string subdomain { get; set; }
    public string cellBackendPool { get; set; }
    public string cellName { get; set; }
    public TenantTier? tenantTier { get; set; } = TenantTier.Shared;
    public string region { get; set; } = "eastus";
    public List<string> complianceRequirements { get; set; } = new List<string>();
    public TenantStatus status { get; set; } = TenantStatus.Active;
    public DateTime createdDate { get; set; }
    public DateTime? lastModifiedDate { get; set; }
    public int estimatedMonthlyApiCalls { get; set; } = 10000;
    public string contactEmail { get; set; }
    public string organizationName { get; set; }
}

/// <summary>
/// CELL information for capacity and assignment tracking
/// </summary>
public class CellInfo
{
    public string cellId { get; set; }
    public string cellName { get; set; }
    public CellType cellType { get; set; }
    public string region { get; set; }
    public string backendPool { get; set; }
    public int maxTenantCount { get; set; }
    public int currentTenantCount { get; set; }
    public CellStatus status { get; set; }
    public List<string> complianceFeatures { get; set; } = new List<string>();
    public DateTime createdDate { get; set; }
    public DateTime? lastModifiedDate { get; set; }
    public double cpuUtilization { get; set; }
    public double memoryUtilization { get; set; }
    public double storageUtilization { get; set; }
}

/// <summary>
/// Result of CELL assignment operation
/// </summary>
public class CellAssignmentResult
{
    public bool Success { get; set; }
    public string CellBackendPool { get; set; }
    public string CellName { get; set; }
    public string ErrorMessage { get; set; }
}

/// <summary>
/// Tenant tier enumeration for flexible tenancy models
/// </summary>
public enum TenantTier
{
    Startup,     // Small tenants, shared CELLs, cost-optimized
    SMB,         // Small-medium business, shared CELLs, standard features
    Shared,      // General shared tenancy model
    Enterprise,  // Large enterprise, dedicated CELLs, premium features
    Dedicated    // Dedicated infrastructure, full isolation
}

/// <summary>
/// CELL type enumeration
/// </summary>
public enum CellType
{
    Shared,      // Multi-tenant CELL (10-100 tenants)
    Dedicated    // Single-tenant CELL (1 enterprise tenant)
}

/// <summary>
/// Tenant status enumeration
/// </summary>
public enum TenantStatus
{
    Active,
    Inactive,
    Suspended,
    Migrating
}

/// <summary>
/// CELL status enumeration
/// </summary>
public enum CellStatus
{
    Active,
    Provisioning,
    Maintenance,
    Deprecated
}