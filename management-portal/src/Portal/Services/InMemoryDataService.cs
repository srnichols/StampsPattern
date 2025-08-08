using Stamps.ManagementPortal.Models;

namespace Stamps.ManagementPortal.Services;

public class InMemoryDataService : IDataService
{
    private static readonly List<Tenant> Tenants = new()
    {
        new("contoso","Contoso","contoso.com","enterprise","active","cell-eastus-1"),
        new("fabrikam","Fabrikam","fabrikam.io","smb","active","cell-westus-1")
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
}
