using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace TaskTracker.Blazor.Models;

public class SiteSettings
{
    // One document per tenant; keep id constant by convention
    [Required]
    [JsonPropertyName("id")]
    public string Id { get; set; } = "settings";

    [StringLength(200)]
    [JsonPropertyName("dashboardTitle")]
    public string? DashboardTitle { get; set; }

    // Store hex color; restrict choices in UI
    [StringLength(7)]
    [JsonPropertyName("themeColor")]
    public string? ThemeColor { get; set; } = "#0d6efd"; // Bootstrap primary

    [StringLength(200)]
    [JsonPropertyName("domain")]
    public string? Domain { get; set; }

    [Required]
    [StringLength(200)]
    [JsonPropertyName("tenantId")]
    public string TenantId { get; set; } = string.Empty;

    [JsonPropertyName("updatedAtUtc")]
    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
}
