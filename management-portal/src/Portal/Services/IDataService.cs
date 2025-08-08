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

    // Cell CRUD
    Task<Cell> CreateCellAsync(Cell cell, CancellationToken ct = default);
    Task<Cell> UpdateCellAsync(Cell cell, CancellationToken ct = default);
    Task DeleteCellAsync(string id, string partitionKey, CancellationToken ct = default);

    // Operation CRUD
    Task<Operation> CreateOperationAsync(Operation op, CancellationToken ct = default);
    Task<Operation> UpdateOperationAsync(Operation op, CancellationToken ct = default);
    Task DeleteOperationAsync(string id, string partitionKey, CancellationToken ct = default);
}
