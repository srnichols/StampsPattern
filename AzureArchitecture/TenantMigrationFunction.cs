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

/// <summary>
/// Azure Function for migrating tenants between CELL types (Shared → Dedicated)
/// Supports the flexible tenancy model documented in ARCHITECTURE_GUIDE.md
/// </summary>
public class TenantMigrationFunction
{
    private readonly CosmosClient _cosmosClient;
    private readonly Container _tenantsContainer;
    private readonly Container _cellsContainer;
    private readonly ILogger<TenantMigrationFunction> _logger;

    // Use dependency injection for better testability
    public TenantMigrationFunction(CosmosClient cosmosClient, ILogger<TenantMigrationFunction> logger)
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
    public TenantMigrationFunction() : this(
        new CosmosClient(Environment.GetEnvironmentVariable("CosmosDbConnection") ?? 
            throw new InvalidOperationException("CosmosDbConnection not configured")),
        LoggerFactory.Create(builder => builder.AddConsole()).CreateLogger<TenantMigrationFunction>())
    {
    }

    /// <summary>
    /// Migrate tenant from Shared to Dedicated CELL
    /// POST /api/tenant/{tenantId}/migrate
    /// </summary>
    [Function("MigrateTenant")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "tenant/{tenantId}/migrate")] HttpRequestData req)
    {
        string tenantId = req.FunctionContext.BindingContext.BindingData["tenantId"]?.ToString();
        
        if (string.IsNullOrEmpty(tenantId))
        {
            var errorResponse = req.CreateResponse(HttpStatusCode.BadRequest);
            await errorResponse.WriteStringAsync("TenantId is required.");
            return errorResponse;
        }

        var migrationRequest = await req.ReadFromJsonAsync<TenantMigrationRequest>();

        try
        {
            // Get current tenant information
            var currentTenant = await GetTenantAsync(tenantId);
            if (currentTenant == null)
            {
                var notFoundResponse = req.CreateResponse(HttpStatusCode.NotFound);
                await notFoundResponse.WriteStringAsync($"Tenant {tenantId} not found.");
                return notFoundResponse;
            }

            // Validate migration eligibility
            var validationResult = ValidateMigrationEligibility(currentTenant, migrationRequest);
            if (!validationResult.IsValid)
            {
                var validationResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                await validationResponse.WriteStringAsync(validationResult.ErrorMessage);
                return validationResponse;
            }

            // Perform migration
            var migrationResult = await PerformTenantMigrationAsync(currentTenant, migrationRequest);

            if (!migrationResult.Success)
            {
                var migrationResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
                await migrationResponse.WriteStringAsync($"Migration failed: {migrationResult.ErrorMessage}");
                return migrationResponse;
            }

            var successResponse = req.CreateResponse(HttpStatusCode.OK);
            await successResponse.WriteAsJsonAsync(migrationResult);
            return successResponse;
        }
        catch (Exception ex)
        {
            var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
            await errorResponse.WriteStringAsync($"Migration error: {ex.Message}");
            return errorResponse;
        }
    }

    /// <summary>
    /// Get CELL capacity information for monitoring
    /// GET /api/cells/capacity
    /// </summary>
    [Function("GetCellCapacity")]
    public async Task<HttpResponseData> GetCellCapacity(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "cells/capacity")] HttpRequestData req)
    {
        try
        {
            var region = req.Query["region"];
            var cellType = req.Query["cellType"];

            var query = "SELECT * FROM c WHERE c.status = @status";
            var queryDef = new QueryDefinition(query).WithParameter("@status", CellStatus.Active.ToString());

            if (!string.IsNullOrEmpty(region))
            {
                query += " AND c.region = @region";
                queryDef = queryDef.WithParameter("@region", region);
            }

            if (!string.IsNullOrEmpty(cellType) && Enum.TryParse<CellType>(cellType, out var parsedCellType))
            {
                query += " AND c.cellType = @cellType";
                queryDef = new QueryDefinition(query).WithParameter("@cellType", parsedCellType.ToString());
            }

            var cells = new List<CellInfo>();
            var iterator = _cellsContainer.GetItemQueryIterator<CellInfo>(queryDef);

            while (iterator.HasMoreResults)
            {
                var page = await iterator.ReadNextAsync();
                cells.AddRange(page);
            }

            var capacityInfo = cells.Select(c => new CellCapacityInfo
            {
                CellName = c.cellName,
                CellType = c.cellType,
                Region = c.region,
                CurrentTenants = c.currentTenantCount,
                MaxTenants = c.maxTenantCount,
                CapacityPercentage = c.maxTenantCount > 0 ? (double)c.currentTenantCount / c.maxTenantCount * 100 : 0,
                CpuUtilization = c.cpuUtilization,
                MemoryUtilization = c.memoryUtilization,
                StorageUtilization = c.storageUtilization,
                Status = c.status
            }).ToList();

            var ok = req.CreateResponse(HttpStatusCode.OK);
            await ok.WriteAsJsonAsync(new
            {
                TotalCells = capacityInfo.Count,
                SharedCells = capacityInfo.Count(c => c.CellType == CellType.Shared),
                DedicatedCells = capacityInfo.Count(c => c.CellType == CellType.Dedicated),
                AverageCapacity = capacityInfo.Average(c => c.CapacityPercentage),
                Cells = capacityInfo
            });
            return ok;
        }
        catch (Exception ex)
        {
            var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
            await errorResponse.WriteStringAsync($"Error retrieving capacity: {ex.Message}");
            return errorResponse;
        }
    }

    /// <summary>
    /// Get tenant information by ID
    /// </summary>
    private async Task<TenantInfo> GetTenantAsync(string tenantId)
    {
        try
        {
            var read = await _tenantsContainer.ReadItemAsync<TenantInfo>(tenantId, new PartitionKey(tenantId));
            return read.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    /// <summary>
    /// Validate if tenant is eligible for migration
    /// </summary>
    private MigrationValidationResult ValidateMigrationEligibility(TenantInfo tenant, TenantMigrationRequest request)
    {
        // Check if tenant is currently active
        if (tenant.status != TenantStatus.Active)
        {
            return new MigrationValidationResult
            {
                IsValid = false,
                ErrorMessage = $"Tenant must be in Active status. Current status: {tenant.status}"
            };
        }

        // Check if migration direction is valid
        if (tenant.tenantTier == TenantTier.Enterprise || tenant.tenantTier == TenantTier.Dedicated)
        {
            if (request.TargetTenantTier == TenantTier.Shared || request.TargetTenantTier == TenantTier.SMB)
            {
                return new MigrationValidationResult
                {
                    IsValid = false,
                    ErrorMessage = "Cannot migrate from Dedicated/Enterprise to Shared CELL. Data isolation requirements prevent downgrade."
                };
            }
        }

        // Validate compliance requirements can be met
        if (request.RequiredCompliance != null && request.RequiredCompliance.Any())
        {
            // Additional compliance validation logic would go here
        }

        return new MigrationValidationResult { IsValid = true };
    }

    /// <summary>
    /// Perform the actual tenant migration
    /// </summary>
    private async Task<TenantMigrationResult> PerformTenantMigrationAsync(TenantInfo tenant, TenantMigrationRequest request)
    {
        try
        {
            // Step 1: Find or provision target CELL
            var targetCell = await FindOrProvisionTargetCellAsync(tenant.region, request.TargetTenantTier, request.RequiredCompliance);
            
            if (targetCell == null)
            {
                return new TenantMigrationResult
                {
                    Success = false,
                    ErrorMessage = "Unable to find or provision suitable target CELL"
                };
            }

            // Step 2: Update tenant status to Migrating
            tenant.status = TenantStatus.Migrating;
            tenant.lastModifiedDate = DateTime.UtcNow;
            await _tenantsContainer.ReplaceItemAsync(tenant, tenant.tenantId, new PartitionKey(tenant.tenantId));

            // Step 3: Update tenant routing information
            var oldCellBackendPool = tenant.cellBackendPool;
            var oldCellName = tenant.cellName;
            
            tenant.cellBackendPool = targetCell.backendPool;
            tenant.cellName = targetCell.cellName;
            tenant.tenantTier = request.TargetTenantTier;
            tenant.status = TenantStatus.Active;
            tenant.lastModifiedDate = DateTime.UtcNow;

            await _tenantsContainer.ReplaceItemAsync(tenant, tenant.tenantId, new PartitionKey(tenant.tenantId));

            // Step 4: Update CELL tenant counts
            await UpdateCellTenantCountAsync(targetCell.cellId, 1); // Add to new CELL
            await DecrementSourceCellCountAsync(oldCellName); // Remove from old CELL

            // Step 5: TODO: Trigger data migration process
            // This would involve:
            // - Export data from source CELL
            // - Import data to target CELL
            // - Validate data integrity
            // - Update application routing

            return new TenantMigrationResult
            {
                Success = true,
                SourceCell = oldCellName,
                TargetCell = targetCell.cellName,
                MigrationStartTime = DateTime.UtcNow,
                EstimatedCompletionTime = DateTime.UtcNow.AddHours(2), // Estimation
                Message = $"Migration initiated from {oldCellName} to {targetCell.cellName}"
            };
        }
        catch (Exception ex)
        {
            return new TenantMigrationResult
            {
                Success = false,
                ErrorMessage = $"Migration failed: {ex.Message}"
            };
        }
    }

    /// <summary>
    /// Find existing CELL or provision new one for target tenant tier
    /// </summary>
    private async Task<CellInfo> FindOrProvisionTargetCellAsync(string region, TenantTier? targetTier, List<string> requiredCompliance)
    {
        if (targetTier == TenantTier.Enterprise || targetTier == TenantTier.Dedicated)
        {
            // For enterprise/dedicated, always provision new dedicated CELL
            return await ProvisionNewDedicatedCellAsync(region, requiredCompliance);
        }
        else
        {
            // For shared tiers, find existing shared CELL with capacity
            return await FindSharedCellWithCapacityAsync(region, requiredCompliance);
        }
    }

    /// <summary>
    /// Find shared CELL with available capacity
    /// </summary>
    private async Task<CellInfo> FindSharedCellWithCapacityAsync(string region, List<string> requiredCompliance)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.region = @region AND c.cellType = @cellType AND c.status = @status AND c.currentTenantCount < c.maxTenantCount")
            .WithParameter("@region", region)
            .WithParameter("@cellType", CellType.Shared.ToString())
            .WithParameter("@status", CellStatus.Active.ToString());

        var cells = new List<CellInfo>();
        var iterator = _cellsContainer.GetItemQueryIterator<CellInfo>(query);

        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            cells.AddRange(response);
        }

        // Filter by compliance requirements
        if (requiredCompliance != null && requiredCompliance.Any())
        {
            cells = cells.Where(c => requiredCompliance.All(req => c.complianceFeatures.Contains(req))).ToList();
        }

        // Return CELL with lowest tenant count for load balancing
        return cells.OrderBy(c => c.currentTenantCount).FirstOrDefault();
    }

    /// <summary>
    /// Provision new dedicated CELL for migration
    /// </summary>
    private async Task<CellInfo> ProvisionNewDedicatedCellAsync(string region, List<string> requiredCompliance)
    {
        var cellName = $"dedicated-migration-{region}-{Guid.NewGuid().ToString("N")[..8]}";
        var newCell = new CellInfo
        {
            cellId = Guid.NewGuid().ToString(),
            cellName = cellName,
            cellType = CellType.Dedicated,
            region = region,
            backendPool = $"{cellName}-backend",
            maxTenantCount = 1,
            currentTenantCount = 0,
            status = CellStatus.Active, // For migration, assume immediate availability
            complianceFeatures = requiredCompliance ?? new List<string>(),
            createdDate = DateTime.UtcNow
        };

        await _cellsContainer.CreateItemAsync(newCell, new PartitionKey(newCell.cellId));
        return newCell;
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
            cell.Resource.lastModifiedDate = DateTime.UtcNow;
            await _cellsContainer.ReplaceItemAsync(cell.Resource, cellId, new PartitionKey(cellId));
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            // CELL not found - log warning
        }
    }

    /// <summary>
    /// Decrement tenant count in source CELL by name
    /// </summary>
    private async Task DecrementSourceCellCountAsync(string cellName)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.cellName = @cellName")
            .WithParameter("@cellName", cellName);

        var iterator = _cellsContainer.GetItemQueryIterator<CellInfo>(query);
        
        while (iterator.HasMoreResults)
        {
            var page = await iterator.ReadNextAsync();
            foreach (var cell in page)
            {
                cell.currentTenantCount = Math.Max(0, cell.currentTenantCount - 1);
                cell.lastModifiedDate = DateTime.UtcNow;
                await _cellsContainer.ReplaceItemAsync(cell, cell.cellId, new PartitionKey(cell.cellId));
                break; // Only update first match
            }
        }
    }
}

/// <summary>
/// Request model for tenant migration
/// </summary>
public class TenantMigrationRequest
{
    public TenantTier? TargetTenantTier { get; set; }
    public List<string> RequiredCompliance { get; set; } = new List<string>();
    public string Reason { get; set; }
    public bool ForceDataMigration { get; set; } = false;
}

/// <summary>
/// Result of migration validation
/// </summary>
public class MigrationValidationResult
{
    public bool IsValid { get; set; }
    public string ErrorMessage { get; set; }
}

/// <summary>
/// Result of tenant migration operation
/// </summary>
public class TenantMigrationResult
{
    public bool Success { get; set; }
    public string SourceCell { get; set; }
    public string TargetCell { get; set; }
    public DateTime MigrationStartTime { get; set; }
    public DateTime EstimatedCompletionTime { get; set; }
    public string Message { get; set; }
    public string ErrorMessage { get; set; }
}

/// <summary>
/// CELL capacity information for monitoring
/// </summary>
public class CellCapacityInfo
{
    public string CellName { get; set; }
    public CellType CellType { get; set; }
    public string Region { get; set; }
    public int CurrentTenants { get; set; }
    public int MaxTenants { get; set; }
    public double CapacityPercentage { get; set; }
    public double CpuUtilization { get; set; }
    public double MemoryUtilization { get; set; }
    public double StorageUtilization { get; set; }
    public CellStatus Status { get; set; }
}
