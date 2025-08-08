namespace Stamps.ManagementPortal.Models;

public record Tenant(string Id, string DisplayName, string Domain, string Tier, string Status, string CellId);
public record Cell(string Id, string Region, string AvailabilityZone, string Status, int CapacityUsed, int CapacityTotal);
public record Operation(string Id, string TenantId, string Type, string Status, DateTimeOffset CreatedAt);
