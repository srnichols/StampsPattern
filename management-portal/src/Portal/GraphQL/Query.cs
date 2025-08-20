using HotChocolate;
using HotChocolate.Types;
using Stamps.ManagementPortal.Models;
using Stamps.ManagementPortal.Services;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace Stamps.ManagementPortal.GraphQL;

public class Query
{
    private readonly ICosmosDiscoveryService _cosmosDiscoveryService;

    public Query(ICosmosDiscoveryService cosmosDiscoveryService)
    {
        _cosmosDiscoveryService = cosmosDiscoveryService;
    }

    [UsePaging]
    [UseFiltering]
    [UseSorting]
    public async Task<IEnumerable<Tenant>> GetTenantsAsync() => await _cosmosDiscoveryService.DiscoverTenantsAsync();

    [UsePaging]
    [UseFiltering]
    [UseSorting]
    public async Task<IEnumerable<Cell>> GetCellsAsync() => await _cosmosDiscoveryService.DiscoverCellsAsync();
}
