using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace TaskTracker.Blazor.Models;

public class TaskItem
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; } = Guid.NewGuid();
    
    [Required]
    [JsonPropertyName("tenantId")]
    public string TenantId { get; set; } = string.Empty;
    
    [Required, StringLength(200)]
    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;
    
    [StringLength(2000)]
    [JsonPropertyName("description")]
    public string? Description { get; set; }
    
    [JsonPropertyName("categoryId")]
    public Guid? CategoryId { get; set; }
    
    [JsonPropertyName("priority")]
    public Priority Priority { get; set; } = Priority.Mid;
    
    [JsonPropertyName("isArchived")]
    public bool IsArchived { get; set; } = false;
    
    [JsonPropertyName("dueDate")]
    public DateTime? DueDate { get; set; }
    
    [StringLength(50)]
    [JsonPropertyName("icon")]
    public string? Icon { get; set; }
    
    [JsonPropertyName("attachments")]
    public List<Attachment> Attachments { get; set; } = new();
    
    [JsonPropertyName("assigneeUserIds")]
    public List<string> AssigneeUserIds { get; set; } = new();
    
    [Required]
    [JsonPropertyName("createdByUserId")]
    public string CreatedByUserId { get; set; } = string.Empty;
    
    [JsonPropertyName("createdAtUtc")]
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    
    [JsonPropertyName("updatedAtUtc")]
    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
    
    [JsonPropertyName("tagNames")]
    public List<string> TagNames { get; set; } = new();
}

public enum Priority
{
    Low = 1,
    Mid = 2,
    High = 3
}

public class Attachment
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; } = Guid.NewGuid();
    
    [Required]
    [JsonPropertyName("blobUri")]
    public string BlobUri { get; set; } = string.Empty;
    
    [Required, StringLength(255)]
    [JsonPropertyName("fileName")]
    public string FileName { get; set; } = string.Empty;
    
    [Required, StringLength(100)]
    [JsonPropertyName("contentType")]
    public string ContentType { get; set; } = string.Empty;
    
    [JsonPropertyName("sizeBytes")]
    public long SizeBytes { get; set; }
    
    [Required]
    [JsonPropertyName("uploadedByUserId")]
    public string UploadedByUserId { get; set; } = string.Empty;
    
    [JsonPropertyName("uploadedAtUtc")]
    public DateTime UploadedAtUtc { get; set; } = DateTime.UtcNow;
}