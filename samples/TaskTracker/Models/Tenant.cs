using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace TaskTracker.Blazor.Models;

public class Tenant
{
    [Required]
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;
    
    [Required, StringLength(200)]
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
    
    [StringLength(500)]
    [JsonPropertyName("logoUrl")]
    public string? LogoUrl { get; set; }
    
    [StringLength(100)]
    [JsonPropertyName("subdomain")]
    public string? Subdomain { get; set; }
    
    [StringLength(7)]
    [JsonPropertyName("primaryColor")]
    public string? PrimaryColor { get; set; } = "#007bff";
    
    [JsonPropertyName("createdAtUtc")]
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    
    [JsonPropertyName("isActive")]
    public bool IsActive { get; set; } = true;
}

public class UserProfile
{
    [Required]
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;
    
    [Required]
    [JsonPropertyName("tenantId")]
    public string TenantId { get; set; } = string.Empty;
    
    [Required, StringLength(100)]
    [JsonPropertyName("displayName")]
    public string DisplayName { get; set; } = string.Empty;
    
    [Required, StringLength(200)]
    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;
    
    [JsonPropertyName("createdAtUtc")]
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    
    [JsonPropertyName("lastLoginUtc")]
    public DateTime LastLoginUtc { get; set; } = DateTime.UtcNow;
}