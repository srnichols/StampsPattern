using Stamps.ManagementPortal.Models;

namespace Stamps.ManagementPortal.Services;

public interface IDataService
{
    Task<IReadOnlyList<Tenant>> GetTenantsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<Cell>> GetCellsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<Operation>> GetOperationsAsync(CancellationToken ct = default);

    // Tenant CRUD
    Task<Tenant> CreateTenantAsync(Tenant tenant, CancellationToken ct = default);
    Task<Tenant> UpdateTenantAsync(Tenant tenant, CancellationToken ct = default);
    Task DeleteTenantAsync(string id, string partitionKey, CancellationToken ct = default);
}
