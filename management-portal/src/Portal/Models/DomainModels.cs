namespace Stamps.ManagementPortal.Models;

public record Tenant(
    string Id,
    string DisplayName,
    string Domain,
    string Tier,
    string Status,
    string CellId,
    string ContactName,
    string ContactEmail
);
public record Cell(string Id, string Region, string AvailabilityZone, string Status, int CapacityUsed, int CapacityTotal);
public record Operation(string Id, string TenantId, string Type, string Status, DateTimeOffset CreatedAt);

public class DiscoveredCell
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Region { get; set; } = string.Empty;
    public string Status { get; set; } = "unknown";
    public int CapacityTotal { get; set; } = 100;
    public int CapacityUsed { get; set; } = 0;
    public string ResourceGroup { get; set; } = string.Empty;
    public List<string> ResourceTypes { get; set; } = new List<string>();
    
    public double UtilizationPercentage => CapacityTotal > 0 ? (double)CapacityUsed / CapacityTotal * 100 : 0;
    public bool IsHealthy => Status.Equals("healthy", StringComparison.OrdinalIgnoreCase);
}

public class DiscoveredResource
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
    public string ResourceGroup { get; set; } = string.Empty;
}
