using Stamps.ManagementPortal.Models;

namespace Stamps.ManagementPortal.Services;

public interface IDataService
{
    Task<IReadOnlyList<Tenant>> GetTenantsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<Cell>> GetCellsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<Operation>> GetOperationsAsync(CancellationToken ct = default);
}
