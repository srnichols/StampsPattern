using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Stamps.ManagementPortal.Models;

namespace Stamps.ManagementPortal.Services;

public class GraphQLDataService(IHttpClientFactory httpClientFactory, IConfiguration config) : IDataService
{
    private readonly IHttpClientFactory _httpClientFactory = httpClientFactory;
    private readonly IConfiguration _config = config;

    private HttpClient Client => _httpClientFactory.CreateClient("GraphQL");

    public async Task<IReadOnlyList<Tenant>> GetTenantsAsync(CancellationToken ct = default)
        => await QueryAsync<Tenant>("query { Tenants { id displayName domain tier status cellId } }", "Tenants", ct);

    public async Task<IReadOnlyList<Cell>> GetCellsAsync(CancellationToken ct = default)
        => await QueryAsync<Cell>("query { Cells { id region availabilityZone status capacityUsed capacityTotal } }", "Cells", ct);

    public async Task<IReadOnlyList<Operation>> GetOperationsAsync(CancellationToken ct = default)
        => await QueryAsync<Operation>("query { Operations { id tenantId type status createdAt } }", "Operations", ct);

    public async Task<Tenant> CreateTenantAsync(Tenant tenant, CancellationToken ct = default)
    {
        var mutation = @"mutation($input: CreateTenantInput!) {
            createTenant(input: $input) { id displayName domain tier status cellId }
        }";
        var variables = new
        {
            input = new
            {
                id = tenant.Id,
                pk = tenant.Id,
                displayName = tenant.DisplayName,
                domain = tenant.Domain,
                tier = tenant.Tier,
                status = tenant.Status,
                cellId = tenant.CellId
            }
        };
        return await MutationAsync<Tenant>(mutation, variables, "createTenant", ct);
    }

    public async Task<Tenant> UpdateTenantAsync(Tenant tenant, CancellationToken ct = default)
    {
        var mutation = @"mutation($id: ID!, $input: UpdateTenantInput!) {
            updateTenant(id: $id, input: $input) { id displayName domain tier status cellId }
        }";
        var variables = new
        {
            id = tenant.Id,
            input = new
            {
                displayName = tenant.DisplayName,
                domain = tenant.Domain,
                tier = tenant.Tier,
                status = tenant.Status,
                cellId = tenant.CellId
            }
        };
        return await MutationAsync<Tenant>(mutation, variables, "updateTenant", ct);
    }

    public async Task DeleteTenantAsync(string id, string partitionKey, CancellationToken ct = default)
    {
        var mutation = @"mutation($id: ID!, $pk: String!) {
            deleteTenant(id: $id, partitionKeyValue: $pk)
        }";
        var variables = new { id, pk = partitionKey };
        await MutationAsync<object>(mutation, variables, "deleteTenant", ct);
    }

    public async Task<Cell> CreateCellAsync(Cell cell, CancellationToken ct = default)
    {
        var mutation = @"mutation($input: CreateCellInput!) { createCell(input: $input) { id region availabilityZone status capacityUsed capacityTotal } }";
        var variables = new { input = new { id = cell.Id, pk = cell.Id, region = cell.Region, availabilityZone = cell.AvailabilityZone, status = cell.Status, capacityUsed = cell.CapacityUsed, capacityTotal = cell.CapacityTotal } };
        return await MutationAsync<Cell>(mutation, variables, "createCell", ct);
    }

    public async Task<Cell> UpdateCellAsync(Cell cell, CancellationToken ct = default)
    {
        var mutation = @"mutation($id: ID!, $input: UpdateCellInput!) { updateCell(id: $id, input: $input) { id region availabilityZone status capacityUsed capacityTotal } }";
        var variables = new { id = cell.Id, input = new { region = cell.Region, availabilityZone = cell.AvailabilityZone, status = cell.Status, capacityUsed = cell.CapacityUsed, capacityTotal = cell.CapacityTotal } };
        return await MutationAsync<Cell>(mutation, variables, "updateCell", ct);
    }

    public async Task DeleteCellAsync(string id, string partitionKey, CancellationToken ct = default)
    {
        var mutation = @"mutation($id: ID!, $pk: String!) { deleteCell(id: $id, partitionKeyValue: $pk) }";
        var variables = new { id, pk = partitionKey };
        await MutationAsync<object>(mutation, variables, "deleteCell", ct);
    }

    public async Task<Operation> CreateOperationAsync(Operation op, CancellationToken ct = default)
    {
        var mutation = @"mutation($input: CreateOperationInput!) { createOperation(input: $input) { id tenantId type status createdAt } }";
        var variables = new { input = new { id = op.Id, pk = op.TenantId, tenantId = op.TenantId, type = op.Type, status = op.Status, createdAt = op.CreatedAt } };
        return await MutationAsync<Operation>(mutation, variables, "createOperation", ct);
    }

    public async Task<Operation> UpdateOperationAsync(Operation op, CancellationToken ct = default)
    {
        var mutation = @"mutation($id: ID!, $input: UpdateOperationInput!) { updateOperation(id: $id, input: $input) { id tenantId type status createdAt } }";
        var variables = new { id = op.Id, input = new { tenantId = op.TenantId, type = op.Type, status = op.Status, createdAt = op.CreatedAt } };
        return await MutationAsync<Operation>(mutation, variables, "updateOperation", ct);
    }

    public async Task DeleteOperationAsync(string id, string partitionKey, CancellationToken ct = default)
    {
        var mutation = @"mutation($id: ID!, $pk: String!) { deleteOperation(id: $id, partitionKeyValue: $pk) }";
        var variables = new { id, pk = partitionKey };
        await MutationAsync<object>(mutation, variables, "deleteOperation", ct);
    }

    private async Task<IReadOnlyList<T>> QueryAsync<T>(string query, string rootField, CancellationToken ct)
    {
        var payload = new { query };
        using var req = new HttpRequestMessage(HttpMethod.Post, "")
        {
            Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json")
        };
        using var res = await Client.SendAsync(req, ct);
        res.EnsureSuccessStatusCode();
        using var stream = await res.Content.ReadAsStreamAsync(ct);
        using var doc = await JsonDocument.ParseAsync(stream, cancellationToken: ct);
        var data = doc.RootElement.GetProperty("data").GetProperty(rootField);
        var list = new List<T>();
        foreach (var el in data.EnumerateArray())
        {
            var obj = el.Deserialize<T>(new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            if (obj is not null) list.Add(obj);
        }
        return list;
    }

    private async Task<T> MutationAsync<T>(string query, object variables, string rootField, CancellationToken ct)
    {
        var payload = new { query, variables };
        using var req = new HttpRequestMessage(HttpMethod.Post, "")
        {
            Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json")
        };
        using var res = await Client.SendAsync(req, ct);
        res.EnsureSuccessStatusCode();
        using var stream = await res.Content.ReadAsStreamAsync(ct);
        using var doc = await JsonDocument.ParseAsync(stream, cancellationToken: ct);
        var data = doc.RootElement.GetProperty("data").GetProperty(rootField);
        if (typeof(T) == typeof(object)) return default!;
        var result = data.Deserialize<T>(new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        return result!;
    }
}
