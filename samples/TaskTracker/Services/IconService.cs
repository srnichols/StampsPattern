namespace TaskTracker.Blazor.Services;

public interface IIconService
{
    Dictionary<string, IconDefinition> GetAvailableIcons();
    string GetIconGlyph(string? iconKey);
    string GetIconTooltip(string? iconKey);
    string GetIconCategory(string? iconKey);
}

public class IconDefinition
{
    public required string Key { get; init; }
    public required string Glyph { get; init; }
    public required string Tooltip { get; init; }
    public required string Category { get; init; }
}

public class IconService : IIconService
{
    private readonly Dictionary<string, IconDefinition> _icons = new()
    {
        ["general.star"] = new() { Key = "general.star", Glyph = "⭐", Tooltip = "Important", Category = "General" },
        ["general.check"] = new() { Key = "general.check", Glyph = "✅", Tooltip = "Complete", Category = "General" },
        ["planning.note"] = new() { Key = "planning.note", Glyph = "📝", Tooltip = "Planning/Notes", Category = "Planning" },
        ["bug.issue"] = new() { Key = "bug.issue", Glyph = "🐛", Tooltip = "Bug/Issue", Category = "Development" },
        ["docs.book"] = new() { Key = "docs.book", Glyph = "📚", Tooltip = "Documentation", Category = "Documentation" },
        ["design.palette"] = new() { Key = "design.palette", Glyph = "🎨", Tooltip = "Design/UX", Category = "Design" },
        ["meeting.talk"] = new() { Key = "meeting.talk", Glyph = "🗣️", Tooltip = "Meeting/Discussion", Category = "Communication" },
        ["ops.wrench"] = new() { Key = "ops.wrench", Glyph = "🔧", Tooltip = "Operations", Category = "Operations" },
        ["data.db"] = new() { Key = "data.db", Glyph = "🗄️", Tooltip = "Data/Storage", Category = "Data" },
        ["code.brackets"] = new() { Key = "code.brackets", Glyph = "🧩", Tooltip = "Coding Task", Category = "Development" },
        ["review.magnifier"] = new() { Key = "review.magnifier", Glyph = "🔍", Tooltip = "Review", Category = "Quality" },
        ["test.lab"] = new() { Key = "test.lab", Glyph = "🧪", Tooltip = "Testing", Category = "Quality" },
        ["deploy.rocket"] = new() { Key = "deploy.rocket", Glyph = "🚀", Tooltip = "Deployment", Category = "Operations" },
        ["alert.warning"] = new() { Key = "alert.warning", Glyph = "⚠️", Tooltip = "Attention/Blocked", Category = "Alerts" },
        ["time.clock"] = new() { Key = "time.clock", Glyph = "🕒", Tooltip = "Time-sensitive", Category = "Time" },
    ["idea.bulb"] = new() { Key = "idea.bulb", Glyph = "💡", Tooltip = "Idea", Category = "Innovation" },

    // Security
    ["security.lock"] = new() { Key = "security.lock", Glyph = "🔒", Tooltip = "Security", Category = "Security" },
    ["security.shield"] = new() { Key = "security.shield", Glyph = "🛡️", Tooltip = "Hardening", Category = "Security" },

    // DevOps
    ["devops.pipeline"] = new() { Key = "devops.pipeline", Glyph = "🔁", Tooltip = "CI/CD Pipeline", Category = "DevOps" },
    ["devops.container"] = new() { Key = "devops.container", Glyph = "🐳", Tooltip = "Containers", Category = "DevOps" },
    ["devops.automation"] = new() { Key = "devops.automation", Glyph = "🤖", Tooltip = "Automation", Category = "DevOps" },

    // Cloud / Infra
    ["infra.cloud"] = new() { Key = "infra.cloud", Glyph = "☁️", Tooltip = "Cloud/Infra", Category = "Infrastructure" },
    ["infra.network"] = new() { Key = "infra.network", Glyph = "🌐", Tooltip = "Networking", Category = "Infrastructure" },
    ["infra.server"] = new() { Key = "infra.server", Glyph = "🖥️", Tooltip = "Servers/VMs", Category = "Infrastructure" },

    // Monitoring & Analytics
    ["monitoring.graph"] = new() { Key = "monitoring.graph", Glyph = "📈", Tooltip = "Monitoring/SLIs", Category = "Monitoring" },
    ["monitoring.logs"] = new() { Key = "monitoring.logs", Glyph = "🧾", Tooltip = "Logs/Tracing", Category = "Monitoring" },
    ["incident.alert"] = new() { Key = "incident.alert", Glyph = "🚨", Tooltip = "Incident", Category = "Monitoring" },

    // Support / Customer
    ["support.headset"] = new() { Key = "support.headset", Glyph = "🎧", Tooltip = "Support", Category = "Customer" },
    ["support.ticket"] = new() { Key = "support.ticket", Glyph = "🎫", Tooltip = "Ticket", Category = "Customer" },

    // Product
    ["product.roadmap"] = new() { Key = "product.roadmap", Glyph = "🗺️", Tooltip = "Roadmap", Category = "Product" },
    ["product.feature"] = new() { Key = "product.feature", Glyph = "✨", Tooltip = "Feature", Category = "Product" },

    // Finance
    ["finance.budget"] = new() { Key = "finance.budget", Glyph = "💰", Tooltip = "Budget/Cost", Category = "Finance" },
    ["finance.invoice"] = new() { Key = "finance.invoice", Glyph = "🧾", Tooltip = "Invoice/Billing", Category = "Finance" },

    // Legal / Compliance
    ["legal.scales"] = new() { Key = "legal.scales", Glyph = "⚖️", Tooltip = "Legal", Category = "Compliance" },
    ["compliance.audit"] = new() { Key = "compliance.audit", Glyph = "📝", Tooltip = "Audit/Compliance", Category = "Compliance" },

    // People / HR
    ["people.user"] = new() { Key = "people.user", Glyph = "👤", Tooltip = "User/Person", Category = "People" },
    ["people.team"] = new() { Key = "people.team", Glyph = "👥", Tooltip = "Team", Category = "People" },
    ["people.hiring"] = new() { Key = "people.hiring", Glyph = "🧑‍💼", Tooltip = "Hiring/Recruiting", Category = "People" },

    // Marketing / Sales
    ["marketing.campaign"] = new() { Key = "marketing.campaign", Glyph = "📣", Tooltip = "Campaign", Category = "Marketing" },
    ["marketing.analytics"] = new() { Key = "marketing.analytics", Glyph = "📊", Tooltip = "Analytics", Category = "Marketing" },
    ["sales.deal"] = new() { Key = "sales.deal", Glyph = "🤝", Tooltip = "Deal/Opportunity", Category = "Sales" },

    // Research / Performance / Mobile / AI
    ["research.lab"] = new() { Key = "research.lab", Glyph = "🔬", Tooltip = "Research/Spike", Category = "Research" },
    ["performance.speed"] = new() { Key = "performance.speed", Glyph = "⚡", Tooltip = "Performance", Category = "Quality" },
    ["mobile.app"] = new() { Key = "mobile.app", Glyph = "�", Tooltip = "Mobile", Category = "Development" },
    ["ai.robot"] = new() { Key = "ai.robot", Glyph = "🤖", Tooltip = "AI/ML", Category = "Innovation" },
    ["ai.brain"] = new() { Key = "ai.brain", Glyph = "🧠", Tooltip = "Modeling", Category = "Innovation" },

    // Data Pipelines
    ["data.pipeline"] = new() { Key = "data.pipeline", Glyph = "🔗", Tooltip = "Data Pipeline", Category = "Data" },
    ["data.migration"] = new() { Key = "data.migration", Glyph = "🔄", Tooltip = "Data Migration", Category = "Data" },

    // Maintenance / Release / Docs / Time
    ["maintenance.broom"] = new() { Key = "maintenance.broom", Glyph = "🧹", Tooltip = "Cleanup/Maintenance", Category = "Operations" },
    ["release.tag"] = new() { Key = "release.tag", Glyph = "🏷️", Tooltip = "Release/Tag", Category = "Operations" },
    ["docs.page"] = new() { Key = "docs.page", Glyph = "📄", Tooltip = "Docs/Spec", Category = "Documentation" },
    ["time.calendar"] = new() { Key = "time.calendar", Glyph = "📅", Tooltip = "Calendar", Category = "Time" }
    };

    public Dictionary<string, IconDefinition> GetAvailableIcons() => _icons;

    public string GetIconGlyph(string? iconKey)
    {
        if (string.IsNullOrEmpty(iconKey) || !_icons.TryGetValue(iconKey, out var icon))
            return "📋"; // Default task icon
        
        return icon.Glyph;
    }

    public string GetIconTooltip(string? iconKey)
    {
        if (string.IsNullOrEmpty(iconKey) || !_icons.TryGetValue(iconKey, out var icon))
            return "Task";
        
        return icon.Tooltip;
    }

    public string GetIconCategory(string? iconKey)
    {
        if (string.IsNullOrEmpty(iconKey) || !_icons.TryGetValue(iconKey, out var icon))
            return "Uncategorized";
        return icon.Category;
    }
}