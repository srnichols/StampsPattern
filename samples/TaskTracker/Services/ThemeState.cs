namespace TaskTracker.Blazor.Services;

public class ThemeState
{
    private const string DefaultColor = "#0d6efd"; // default blue
    private readonly Dictionary<string, string> _colors = new(StringComparer.OrdinalIgnoreCase);

    // (tenantId, color)
    public event Action<string, string>? OnThemeChanged;

    public string GetColor(string? tenantId)
    {
        var key = tenantId ?? string.Empty;
        return _colors.TryGetValue(key, out var color) ? color : DefaultColor;
    }

    public void SetColor(string? tenantId, string? hex)
    {
        var key = tenantId ?? string.Empty;
        var newColor = string.IsNullOrWhiteSpace(hex) ? DefaultColor : hex!.Trim();
        if (!_colors.TryGetValue(key, out var existing) || !string.Equals(existing, newColor, StringComparison.OrdinalIgnoreCase))
        {
            _colors[key] = newColor;
            OnThemeChanged?.Invoke(key, newColor);
        }
    }
}
