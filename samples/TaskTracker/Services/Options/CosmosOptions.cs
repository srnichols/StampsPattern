namespace TaskTracker.Blazor.Services.Options;

public class CosmosOptions
{
    public string? ConnectionString { get; set; }
    public string DatabaseName { get; set; } = "TaskTrackerDb";
}
