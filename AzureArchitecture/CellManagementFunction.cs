using System;
using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Cosmos;
using System.Text.Json;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;
// Timer extension optional: guarded below with compile symbol
using AzureStampsPattern.Models;

/// <summary>
/// Azure Function for CELL management and monitoring
/// Supports automated capacity planning and CELL provisioning for flexible tenancy
/// </summary>
public class CellManagementFunction
{
    private readonly CosmosClient _cosmosClient;
    private readonly Container _tenantsContainer;
    private readonly Container _cellsContainer;

    public CellManagementFunction()
    {
        string cosmosDbConnectionString = Environment.GetEnvironmentVariable("CosmosDbConnection");
        string databaseName = Environment.GetEnvironmentVariable("CosmosDbDatabaseName") ?? "globaldb";
        string tenantsContainerName = Environment.GetEnvironmentVariable("TenantsContainerName") ?? "tenants";
        string cellsContainerName = Environment.GetEnvironmentVariable("CellsContainerName") ?? "cells";
        
        _cosmosClient = new CosmosClient(cosmosDbConnectionString);
        _tenantsContainer = _cosmosClient.GetContainer(databaseName, tenantsContainerName);
        _cellsContainer = _cosmosClient.GetContainer(databaseName, cellsContainerName);
    }

    /// <summary>
    /// Capacity monitoring entrypoint (Timer, optional) or HTTP fallback when Timer extension not available
    /// </summary>
#if TIMER_TRIGGER
    [Function("MonitorCellCapacity")]
    public async Task MonitorCapacity([TimerTrigger("0 */15 * * * *")] Microsoft.Azure.Functions.Worker.Extensions.Timer.TimerInfo timer)
    {
        await RunCapacityMonitoringAsync();
    }
#endif

    [Function("MonitorCellCapacityNow")]
    public async Task<HttpResponseData> MonitorCapacityNow(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "cells/capacity/run")] HttpRequestData req)
    {
        await RunCapacityMonitoringAsync();
        var resp = req.CreateResponse(HttpStatusCode.Accepted);
        await resp.WriteStringAsync("Capacity monitoring executed.");
        return resp;
    }

    private async Task RunCapacityMonitoringAsync()
    {
        try
        {
            var capacityReport = await GenerateCapacityReportAsync();
            foreach (var regionReport in capacityReport.RegionReports)
            {
                await CheckAndProvisionCellsAsync(regionReport);
            }
            Console.WriteLine($"Capacity monitoring completed at {DateTime.UtcNow}");
            Console.WriteLine($"Total CELLs: {capacityReport.TotalCells}");
            Console.WriteLine($"Shared CELLs at capacity: {capacityReport.SharedCellsAtCapacity}");
            Console.WriteLine($"New CELLs provisioned: {capacityReport.NewCellsProvisioned}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error during capacity monitoring: {ex.Message}");
        }
    }

    /// <summary>
    /// HTTP-triggered function to manually provision a new CELL
    /// POST /api/cells/provision
    /// </summary>
    [Function("ProvisionCell")]
    public async Task<HttpResponseData> ProvisionCell(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "cells/provision")] HttpRequestData req)
    {
        try
        {
            var provisionRequest = await req.ReadFromJsonAsync<CellProvisionRequest>();

            // Validate request
            if (string.IsNullOrEmpty(provisionRequest.Region))
            {
                var errorResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                await errorResponse.WriteStringAsync("Region is required.");
                return errorResponse;
            }

            // Check if we're within limits
            var currentCellCount = await GetCellCountInRegionAsync(provisionRequest.Region);
            var maxCells = GetMaxCellsPerRegion();

            if (currentCellCount >= maxCells)
            {
                var limitResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                await limitResponse.WriteStringAsync($"Maximum CELL limit ({maxCells}) reached for region {provisionRequest.Region}");
                return limitResponse;
            }

            // Provision new CELL
            var newCell = await ProvisionNewCellAsync(provisionRequest);

            var response = req.CreateResponse(HttpStatusCode.Created);
            await response.WriteAsJsonAsync(new
            {
                Message = "CELL provisioned successfully",
                CellInfo = new
                {
                    newCell.cellId,
                    newCell.cellName,
                    newCell.cellType,
                    newCell.region,
                    newCell.backendPool,
                    newCell.maxTenantCount,
                    newCell.status
                }
            });
            return response;
        }
        catch (Exception ex)
        {
            var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
            await errorResponse.WriteStringAsync($"Error provisioning CELL: {ex.Message}");
            return errorResponse;
        }
    }

    /// <summary>
    /// Get comprehensive capacity analytics
    /// GET /api/cells/analytics
    /// </summary>
    [Function("GetCellAnalytics")]
    public async Task<HttpResponseData> GetAnalytics(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "cells/analytics")] HttpRequestData req)
    {
        try
        {
            var analytics = await GenerateAnalyticsReportAsync();

            var response = req.CreateResponse(HttpStatusCode.OK);
            await response.WriteAsJsonAsync(analytics);
            return response;
        }
        catch (Exception ex)
        {
            var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
            await errorResponse.WriteStringAsync($"Error generating analytics: {ex.Message}");
            return errorResponse;
        }
    }

    /// <summary>
    /// Generate comprehensive capacity report
    /// </summary>
    private async Task<CapacityReport> GenerateCapacityReportAsync()
    {
        var allCells = await GetAllActiveCellsAsync();
        var allTenants = await GetAllActiveTenantsAsync();

        var regionReports = allCells
            .GroupBy(c => c.region)
            .Select(g => new RegionCapacityReport
            {
                Region = g.Key,
                SharedCells = g.Where(c => c.cellType == CellType.Shared).ToList(),
                DedicatedCells = g.Where(c => c.cellType == CellType.Dedicated).ToList(),
                TotalTenants = allTenants.Count(t => t.region == g.Key),
                SharedCellUtilization = CalculateSharedUtilization(g.Where(c => c.cellType == CellType.Shared)),
                NeedsNewSharedCell = CheckIfNeedsNewSharedCell(g.Where(c => c.cellType == CellType.Shared))
            })
            .ToList();

        return new CapacityReport
        {
            Timestamp = DateTime.UtcNow,
            TotalCells = allCells.Count,
            TotalTenants = allTenants.Count,
            SharedCellsAtCapacity = regionReports.Sum(r => r.SharedCells.Count(c => (double)c.currentTenantCount / c.maxTenantCount > 0.8)),
            RegionReports = regionReports
        };
    }

    /// <summary>
    /// Check and provision CELLs for a region if needed
    /// </summary>
    private async Task CheckAndProvisionCellsAsync(RegionCapacityReport regionReport)
    {
        // Provision new shared CELL if needed
        if (regionReport.NeedsNewSharedCell)
        {
            var newSharedCell = await ProvisionNewCellAsync(new CellProvisionRequest
            {
                Region = regionReport.Region,
                CellType = CellType.Shared,
                Reason = "Automated provisioning - shared CELL capacity threshold reached"
            });

            Console.WriteLine($"Auto-provisioned new shared CELL: {newSharedCell.cellName} in {regionReport.Region}");
        }

        // Check for enterprise tenant backlog (would require additional logic to track requests)
        await CheckEnterpriseBacklogAsync(regionReport.Region);
    }

    /// <summary>
    /// Check for enterprise tenants waiting for dedicated CELLs
    /// </summary>
    private async Task CheckEnterpriseBacklogAsync(string region)
    {
        // Query for enterprise tenants in shared CELLs (indicating they need migration)
        var query = new QueryDefinition("SELECT * FROM c WHERE c.region = @region AND (c.tenantTier = @enterprise OR c.tenantTier = @dedicated) AND c.status = @active")
            .WithParameter("@region", region)
            .WithParameter("@enterprise", TenantTier.Enterprise.ToString())
            .WithParameter("@dedicated", TenantTier.Dedicated.ToString())
            .WithParameter("@active", TenantStatus.Active.ToString());

        var enterpriseTenants = new List<TenantInfo>();
        var iterator = _tenantsContainer.GetItemQueryIterator<TenantInfo>(query);

        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            enterpriseTenants.AddRange(response);
        }

        // Check if any enterprise tenants are in shared CELLs
        var tenantsNeedingDedicatedCell = enterpriseTenants.Where(t => 
            t.cellName != null && t.cellName.StartsWith("shared")).ToList();

        if (tenantsNeedingDedicatedCell.Any())
        {
            Console.WriteLine($"Found {tenantsNeedingDedicatedCell.Count} enterprise tenants in shared CELLs in {region}");
            // In production, this would trigger migration workflows
        }
    }

    /// <summary>
    /// Provision a new CELL based on request
    /// </summary>
    private async Task<CellInfo> ProvisionNewCellAsync(CellProvisionRequest request)
    {
        var cellName = request.CellType == CellType.Shared 
            ? $"shared-{request.Region}-{Guid.NewGuid().ToString("N")[..8]}"
            : $"dedicated-{request.Region}-{Guid.NewGuid().ToString("N")[..8]}";

        var newCell = new CellInfo
        {
            cellId = Guid.NewGuid().ToString(),
            cellName = cellName,
            cellType = request.CellType,
            region = request.Region,
            backendPool = $"{cellName}-backend",
            maxTenantCount = request.CellType == CellType.Shared ? GetMaxTenantsPerSharedCell() : 1,
            currentTenantCount = 0,
            status = CellStatus.Provisioning,
            complianceFeatures = request.ComplianceFeatures ?? new List<string>(),
            createdDate = DateTime.UtcNow,
            cpuUtilization = 0,
            memoryUtilization = 0,
            storageUtilization = 0
        };

        await _cellsContainer.CreateItemAsync(newCell, new PartitionKey(newCell.cellId));

        // TODO: In production, trigger actual Azure resource provisioning
        // This would call ARM templates, Bicep deployments, or Azure Resource Manager APIs
        
        // Simulate provisioning delay and then mark as active
        await Task.Delay(1000); // Simulate provisioning time
        newCell.status = CellStatus.Active;
        await _cellsContainer.ReplaceItemAsync(newCell, newCell.cellId, new PartitionKey(newCell.cellId));

        return newCell;
    }

    /// <summary>
    /// Generate detailed analytics report
    /// </summary>
    private async Task<CellAnalyticsReport> GenerateAnalyticsReportAsync()
    {
        var allCells = await GetAllActiveCellsAsync();
        var allTenants = await GetAllActiveTenantsAsync();

        var tenantDistribution = allTenants
            .GroupBy(t => t.tenantTier)
            .ToDictionary(g => g.Key.ToString(), g => g.Count());

        var regionAnalytics = allCells
            .GroupBy(c => c.region)
            .Select(g => new RegionAnalytics
            {
                Region = g.Key,
                TotalCells = g.Count(),
                SharedCells = g.Count(c => c.cellType == CellType.Shared),
                DedicatedCells = g.Count(c => c.cellType == CellType.Dedicated),
                TotalTenants = allTenants.Count(t => t.region == g.Key),
                AverageCapacityUtilization = g.Average(c => c.maxTenantCount > 0 ? (double)c.currentTenantCount / c.maxTenantCount * 100 : 0),
                CostOptimizationScore = CalculateCostOptimizationScore(g.ToList(), allTenants.Where(t => t.region == g.Key).ToList())
            })
            .ToList();

        return new CellAnalyticsReport
        {
            GeneratedAt = DateTime.UtcNow,
            TotalCells = allCells.Count,
            TotalTenants = allTenants.Count,
            TenantDistribution = tenantDistribution,
            GlobalCapacityUtilization = allCells.Average(c => c.maxTenantCount > 0 ? (double)c.currentTenantCount / c.maxTenantCount * 100 : 0),
            RegionAnalytics = regionAnalytics,
            RecommendedActions = GenerateRecommendations(allCells, allTenants)
        };
    }

    /// <summary>
    /// Calculate cost optimization score for a region
    /// </summary>
    private double CalculateCostOptimizationScore(List<CellInfo> cells, List<TenantInfo> tenants)
    {
        if (!cells.Any()) return 100;

        var sharedCells = cells.Where(c => c.cellType == CellType.Shared).ToList();
        var dedicatedCells = cells.Where(c => c.cellType == CellType.Dedicated).ToList();

        // Calculate efficiency metrics
        var sharedEfficiency = sharedCells.Any() 
            ? sharedCells.Average(c => c.maxTenantCount > 0 ? (double)c.currentTenantCount / c.maxTenantCount : 0)
            : 0;

        var dedicatedUtilization = dedicatedCells.Count(c => c.currentTenantCount > 0) / (double)Math.Max(1, dedicatedCells.Count);

        // Score based on efficient use of resources
        return (sharedEfficiency * 0.6 + dedicatedUtilization * 0.4) * 100;
    }

    /// <summary>
    /// Generate actionable recommendations
    /// </summary>
    private List<string> GenerateRecommendations(List<CellInfo> allCells, List<TenantInfo> allTenants)
    {
        var recommendations = new List<string>();

        // Check for underutilized shared CELLs
        var underutilizedShared = allCells.Where(c => 
            c.cellType == CellType.Shared && 
            c.currentTenantCount < c.maxTenantCount * 0.3).ToList();

        if (underutilizedShared.Any())
        {
            recommendations.Add($"Consider consolidating {underutilizedShared.Count} underutilized shared CELLs to reduce costs");
        }

        // Check for empty dedicated CELLs
        var emptyDedicated = allCells.Where(c => 
            c.cellType == CellType.Dedicated && 
            c.currentTenantCount == 0).ToList();

        if (emptyDedicated.Any())
        {
            recommendations.Add($"Found {emptyDedicated.Count} empty dedicated CELLs that can be deprovisioned");
        }

        // Check for enterprise tenants in shared CELLs
        var enterpriseInShared = allTenants.Where(t => 
            (t.tenantTier == TenantTier.Enterprise || t.tenantTier == TenantTier.Dedicated) &&
            t.cellName != null && t.cellName.StartsWith("shared")).Count();

        if (enterpriseInShared > 0)
        {
            recommendations.Add($"Consider migrating {enterpriseInShared} enterprise tenants to dedicated CELLs for better performance and isolation");
        }

        return recommendations;
    }

    /// <summary>
    /// Helper methods for data retrieval and calculations
    /// </summary>
    private async Task<List<CellInfo>> GetAllActiveCellsAsync()
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.status = @status")
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

    private async Task<List<TenantInfo>> GetAllActiveTenantsAsync()
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.status = @status")
            .WithParameter("@status", TenantStatus.Active.ToString());

        var tenants = new List<TenantInfo>();
        var iterator = _tenantsContainer.GetItemQueryIterator<TenantInfo>(query);

        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            tenants.AddRange(response);
        }

        return tenants;
    }

    private async Task<int> GetCellCountInRegionAsync(string region)
    {
        var query = new QueryDefinition("SELECT VALUE COUNT(1) FROM c WHERE c.region = @region AND c.status = @status")
            .WithParameter("@region", region)
            .WithParameter("@status", CellStatus.Active.ToString());

        var iterator = _cellsContainer.GetItemQueryIterator<int>(query);
        var response = await iterator.ReadNextAsync();
        return response.First();
    }

    private double CalculateSharedUtilization(IEnumerable<CellInfo> sharedCells)
    {
        if (!sharedCells.Any()) return 0;
        return sharedCells.Average(c => c.maxTenantCount > 0 ? (double)c.currentTenantCount / c.maxTenantCount : 0);
    }

    private bool CheckIfNeedsNewSharedCell(IEnumerable<CellInfo> sharedCells)
    {
        var cells = sharedCells.ToList();
        if (!cells.Any()) return true; // Need at least one shared CELL

        // Need new CELL if all existing shared CELLs are >80% capacity
        return cells.All(c => (double)c.currentTenantCount / c.maxTenantCount > 0.8);
    }

    private int GetMaxCellsPerRegion()
    {
        return int.Parse(Environment.GetEnvironmentVariable("MaxCellsPerRegion") ?? "20");
    }

    private int GetMaxTenantsPerSharedCell()
    {
        return int.Parse(Environment.GetEnvironmentVariable("MaxTenantsPerSharedCell") ?? "100");
    }
}

/// <summary>
/// Request model for CELL provisioning
/// </summary>
public class CellProvisionRequest
{
    public string Region { get; set; }
    public CellType CellType { get; set; } = CellType.Shared;
    public List<string> ComplianceFeatures { get; set; }
    public string Reason { get; set; }
}

/// <summary>
/// Capacity monitoring report
/// </summary>
public class CapacityReport
{
    public DateTime Timestamp { get; set; }
    public int TotalCells { get; set; }
    public int TotalTenants { get; set; }
    public int SharedCellsAtCapacity { get; set; }
    public int NewCellsProvisioned { get; set; }
    public List<RegionCapacityReport> RegionReports { get; set; } = new List<RegionCapacityReport>();
}

/// <summary>
/// Regional capacity report
/// </summary>
public class RegionCapacityReport
{
    public string Region { get; set; }
    public List<CellInfo> SharedCells { get; set; } = new List<CellInfo>();
    public List<CellInfo> DedicatedCells { get; set; } = new List<CellInfo>();
    public int TotalTenants { get; set; }
    public double SharedCellUtilization { get; set; }
    public bool NeedsNewSharedCell { get; set; }
}

/// <summary>
/// Comprehensive analytics report
/// </summary>
public class CellAnalyticsReport
{
    public DateTime GeneratedAt { get; set; }
    public int TotalCells { get; set; }
    public int TotalTenants { get; set; }
    public Dictionary<string, int> TenantDistribution { get; set; }
    public double GlobalCapacityUtilization { get; set; }
    public List<RegionAnalytics> RegionAnalytics { get; set; } = new List<RegionAnalytics>();
    public List<string> RecommendedActions { get; set; } = new List<string>();
}

/// <summary>
/// Regional analytics information
/// </summary>
public class RegionAnalytics
{
    public string Region { get; set; }
    public int TotalCells { get; set; }
    public int SharedCells { get; set; }
    public int DedicatedCells { get; set; }
    public int TotalTenants { get; set; }
    public double AverageCapacityUtilization { get; set; }
    public double CostOptimizationScore { get; set; }
}
