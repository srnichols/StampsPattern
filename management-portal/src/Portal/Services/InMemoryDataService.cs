using Stamps.ManagementPortal.Models;

namespace Stamps.ManagementPortal.Services;

public class InMemoryDataService : IDataService
{
    private static readonly List<Tenant> Tenants = new()
    {
        new("contoso", "Contoso Ltd.", "contoso.com", "enterprise", "active", "cell-eastus-1", "Alice Contoso", "admin@contoso.com"),
        new("fabrikam", "Fabrikam, Inc.", "fabrikam.com", "smb", "active", "cell-westus-1", "Bob Fabrikam", "admin@fabrikam.com"),
        new("adventureworks", "Adventure Works", "adventure-works.com", "premium", "active", "cell-eastus-2", "Cathy Adventure", "admin@adventure-works.com"),
        new("northwind", "Northwind Traders", "northwindtraders.com", "standard", "active", "cell-westus-2", "Nick Northwind", "admin@northwindtraders.com"),
        new("tailspintoys", "Tailspin Toys", "tailspintoys.com", "standard", "active", "cell-centralus-1", "Tina Tailspin", "admin@tailspintoys.com"),
        new("wingtiptoys", "Wingtip Toys", "wingtiptoys.com", "standard", "active", "cell-centralus-2", "Will Wingtip", "admin@wingtiptoys.com"),
        new("litware", "Litware, Inc.", "litware.com", "premium", "active", "cell-eastus-3", "Liam Litware", "admin@litware.com"),
        new("woodgrove", "Woodgrove Bank", "woodgrovebank.com", "standard", "active", "cell-westus-3", "Wendy Woodgrove", "admin@woodgrovebank.com"),
        new("blueyonder", "Blue Yonder Airlines", "blueyonderairlines.com", "standard", "active", "cell-northcentralus-1", "Ben Blueyonder", "admin@blueyonderairlines.com"),
        new("proseware", "Proseware, Inc.", "proseware.com", "standard", "active", "cell-northcentralus-2", "Paula Proseware", "admin@proseware.com"),
        new("gdi", "Graphic Design Institute", "gdi.edu", "standard", "active", "cell-southcentralus-1", "Gina GDI", "admin@gdi.edu"),
        new("vanarsdel", "VanArsdel Ltd.", "vanarsdel.com", "standard", "active", "cell-southcentralus-2", "Victor VanArsdel", "admin@vanarsdel.com"),
        new("fourthcoffee", "Fourth Coffee", "fourthcoffee.com", "standard", "active", "cell-eastus-4", "Fiona Fourth", "admin@fourthcoffee.com"),
        new("consolidated", "Consolidated Messenger", "consolidatedmessenger.com", "standard", "active", "cell-westus-4", "Connie Consolidated", "admin@consolidatedmessenger.com"),
        new("wideworld", "Wide World Importers", "wideworldimporters.com", "premium", "active", "cell-eastus-5", "Walt Wideworld", "admin@wideworldimporters.com")
    };
    private static readonly List<Cell> Cells = new()
    {
        new("cell-eastus-1","eastus","1","healthy",60,100),
        new("cell-westus-1","westus","2","healthy",40,100)
    };
    private static readonly List<Operation> Operations = new()
    {
        new("op-001","contoso","migrate","running", DateTimeOffset.UtcNow.AddMinutes(-12)),
        new("op-002","fabrikam","suspend","completed", DateTimeOffset.UtcNow.AddDays(-1))
    };

    public Task<IReadOnlyList<Tenant>> GetTenantsAsync(CancellationToken ct = default) => Task.FromResult((IReadOnlyList<Tenant>)Tenants.ToList());
    public Task<IReadOnlyList<Cell>> GetCellsAsync(CancellationToken ct = default) => Task.FromResult((IReadOnlyList<Cell>)Cells.ToList());
    public Task<IReadOnlyList<Operation>> GetOperationsAsync(CancellationToken ct = default) => Task.FromResult((IReadOnlyList<Operation>)Operations.ToList());

    public Task<Tenant> CreateTenantAsync(Tenant tenant, CancellationToken ct = default)
    {
        Tenants.Add(tenant);
        return Task.FromResult(tenant);
    }

    public Task<Tenant> UpdateTenantAsync(Tenant tenant, CancellationToken ct = default)
    {
        var idx = Tenants.FindIndex(t => t.Id == tenant.Id);
        if (idx >= 0) Tenants[idx] = tenant;
        return Task.FromResult(tenant);
    }

    public Task DeleteTenantAsync(string id, string partitionKey, CancellationToken ct = default)
    {
        Tenants.RemoveAll(t => t.Id == id);
        return Task.CompletedTask;
    }

    public Task<Cell> CreateCellAsync(Cell cell, CancellationToken ct = default)
    {
        Cells.Add(cell);
        return Task.FromResult(cell);
    }

    public Task<Cell> UpdateCellAsync(Cell cell, CancellationToken ct = default)
    {
        var idx = Cells.FindIndex(c => c.Id == cell.Id);
        if (idx >= 0) Cells[idx] = cell;
        return Task.FromResult(cell);
    }

    public Task DeleteCellAsync(string id, string partitionKey, CancellationToken ct = default)
    {
        Cells.RemoveAll(c => c.Id == id);
        return Task.CompletedTask;
    }

    public Task<Operation> CreateOperationAsync(Operation op, CancellationToken ct = default)
    {
        Operations.Add(op);
        return Task.FromResult(op);
    }

    public Task<Operation> UpdateOperationAsync(Operation op, CancellationToken ct = default)
    {
        var idx = Operations.FindIndex(o => o.Id == op.Id);
        if (idx >= 0) Operations[idx] = op;
        return Task.FromResult(op);
    }

    public Task DeleteOperationAsync(string id, string partitionKey, CancellationToken ct = default)
    {
        Operations.RemoveAll(o => o.Id == id);
        return Task.CompletedTask;
    }

    // Catalogs / Domain reservations (in-memory)
    private static readonly HashSet<string> ReservedDomains = new(StringComparer.OrdinalIgnoreCase)
    {
        "contoso.com", "fabrikam.io"
    };

    public Task<bool> ReserveDomainAsync(string domain, string ownerTenantId, CancellationToken ct = default)
    {
        if (ReservedDomains.Contains(domain)) return Task.FromResult(false);
        ReservedDomains.Add(domain);
        return Task.FromResult(true);
    }

    public Task ReleaseDomainAsync(string domain, CancellationToken ct = default)
    {
        ReservedDomains.Remove(domain);
        return Task.CompletedTask;
    }
}
