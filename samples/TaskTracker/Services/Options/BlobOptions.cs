namespace TaskTracker.Blazor.Services.Options;

public class BlobOptions
{
    public string? ConnectionString { get; set; }
    public string ContainerName { get; set; } = "task-attachments";
}
