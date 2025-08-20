using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Stamps.ManagementPortal.Models;
using Microsoft.Extensions.Logging;

namespace Stamps.ManagementPortal.Services;

public class GraphQLDataService(IHttpClientFactory httpClientFactory, IConfiguration config, ILogger<GraphQLDataService> logger) : IDataService
{
    private readonly IHttpClientFactory _httpClientFactory = httpClientFactory;
    private readonly IConfiguration _config = config;
    private readonly ILogger<GraphQLDataService> _logger = logger;

    private HttpClient Client => _httpClientFactory.CreateClient("GraphQL");

    public async Task<IReadOnlyList<Tenant>> GetTenantsAsync(CancellationToken ct = default)
        => await QueryAsync<Tenant>("query { tenants { id displayName domain tier status cellId } }", "tenants", ct);

    public async Task<IReadOnlyList<Cell>> GetCellsAsync(CancellationToken ct = default)
        => await QueryAsync<Cell>("query { cells { id region availabilityZone status capacityUsed capacityTotal } }", "cells", ct);

    public async Task<IReadOnlyList<Operation>> GetOperationsAsync(CancellationToken ct = default)
        => await QueryAsync<Operation>("query { operations { id tenantId type status createdAt } }", "operations", ct);

    public async Task<Tenant> CreateTenantAsync(Tenant tenant, CancellationToken ct = default)
    {
        var mutation = @"mutation CreateTenant($t: Tenant_input!) { createTenant(item: $t) { id displayName domain tier status cellId } }";
        var variables = new
        {
            t = new
            {
                id = tenant.Id,
                tenantId = tenant.Id,
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
        var mutation = @"mutation UpdateTenant($id: ID!, $input: Tenant_input!) { updateTenant(id: $id, item: $input) { id displayName domain tier status cellId } }";
        var variables = new
        {
            id = tenant.Id,
            input = new
            {
                tenantId = tenant.Id,
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
        var mutation = @"mutation DeleteTenant($id: ID!, $pk: String!) { deleteTenant(id: $id, partitionKeyValue: $pk) }";
        var variables = new { id, pk = partitionKey };
        await MutationAsync<object>(mutation, variables, "deleteTenant", ct);
    }

    public async Task<Cell> CreateCellAsync(Cell cell, CancellationToken ct = default)
    {
        var mutation = @"mutation CreateCell($c: Cell_input!) { createCell(item: $c) { id region availabilityZone status capacityUsed capacityTotal } }";
        var variables = new { c = new { id = cell.Id, cellId = cell.Id, region = cell.Region, availabilityZone = cell.AvailabilityZone, status = cell.Status, capacityUsed = cell.CapacityUsed, capacityTotal = cell.CapacityTotal } };
        return await MutationAsync<Cell>(mutation, variables, "createCell", ct);
    }

    public async Task<Cell> UpdateCellAsync(Cell cell, CancellationToken ct = default)
    {
        var mutation = @"mutation UpdateCell($id: ID!, $input: Cell_input!) { updateCell(id: $id, item: $input) { id region availabilityZone status capacityUsed capacityTotal } }";
        var variables = new { id = cell.Id, input = new { cellId = cell.Id, region = cell.Region, availabilityZone = cell.AvailabilityZone, status = cell.Status, capacityUsed = cell.CapacityUsed, capacityTotal = cell.CapacityTotal } };
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
        var mutation = @"mutation CreateOperation($o: Operation_input!) { createOperation(item: $o) { id tenantId type status createdAt } }";
        var variables = new { o = new { id = op.Id, tenantId = op.TenantId, type = op.Type, status = op.Status, createdAt = op.CreatedAt } };
        return await MutationAsync<Operation>(mutation, variables, "createOperation", ct);
    }

    public async Task<Operation> UpdateOperationAsync(Operation op, CancellationToken ct = default)
    {
        var mutation = @"mutation UpdateOperation($id: ID!, $input: Operation_input!) { updateOperation(id: $id, item: $input) { id tenantId type status createdAt } }";
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
        _logger.LogInformation("Executing GraphQL query: {Query}", query);
        var payload = new { query };
        using var req = new HttpRequestMessage(HttpMethod.Post, "")
        {
            Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json")
        };
        try
        {
            using var res = await Client.SendAsync(req, ct);
            res.EnsureSuccessStatusCode();
            var responseContent = await res.Content.ReadAsStringAsync(ct);
            _logger.LogDebug("GraphQL response: {Response}", responseContent);
            using var doc = JsonDocument.Parse(responseContent);
            // If GraphQL returned errors, surface them clearly
            if (doc.RootElement.TryGetProperty("errors", out var errs) && errs.ValueKind == JsonValueKind.Array && errs.GetArrayLength() > 0)
            {
                _logger.LogError("GraphQL errors: {Errors}", errs.ToString());
                throw new HttpRequestException($"GraphQL errors: {errs}");
            }
            var data = doc.RootElement.GetProperty("data").GetProperty(rootField);
            var list = new List<T>();
            foreach (var el in data.EnumerateArray())
            {
                var obj = el.Deserialize<T>(new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                if (obj is not null) list.Add(obj);
            }
            return list;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error executing GraphQL query: {Query}", query);
            throw;
        }
    }

    private async Task<T> MutationAsync<T>(string query, object variables, string rootField, CancellationToken ct)
    {
        _logger.LogInformation("Executing GraphQL mutation: {Query} with variables {Variables}", query, JsonSerializer.Serialize(variables));
        var payload = new { query, variables };
        using var req = new HttpRequestMessage(HttpMethod.Post, "")
        {
            Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json")
        };
        try
        {
            using var res = await Client.SendAsync(req, ct);
            res.EnsureSuccessStatusCode();
            var responseContent = await res.Content.ReadAsStringAsync(ct);
            _logger.LogDebug("GraphQL mutation response: {Response}", responseContent);
            using var doc = JsonDocument.Parse(responseContent);
            if (doc.RootElement.TryGetProperty("errors", out var errs) && errs.ValueKind == JsonValueKind.Array && errs.GetArrayLength() > 0)
            {
                _logger.LogError("GraphQL mutation errors: {Errors}", errs.ToString());
                throw new HttpRequestException($"GraphQL errors: {errs}");
            }
            var data = doc.RootElement.GetProperty("data").GetProperty(rootField);
            if (typeof(T) == typeof(object)) return default!;
            var result = data.Deserialize<T>(new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            return result!;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error executing GraphQL mutation: {Query}", query);
            throw;
        }
    }

    public async Task<bool> ReserveDomainAsync(string domain, string ownerTenantId, CancellationToken ct = default)
    {
        // Try to create a Catalog item with id=domain, type=domains.
        var mutation = @"mutation ReserveDomain($d: Catalog_input!) { createCatalog(item: $d) { id } }";
        var variables = new { d = new { id = domain, type = "domains", owner = ownerTenantId } };
        try
        {
            await MutationAsync<object>(mutation, variables, "createCatalog", ct);
            return true;
        }
        catch
        {
            return false;
        }
    }

    public async Task ReleaseDomainAsync(string domain, CancellationToken ct = default)
    {
    var mutation = "mutation DeleteDomain($id: ID!) { deleteCatalog(id: $id, partitionKeyValue: \"domains\") }";
        var variables = new { id = domain };
        await MutationAsync<object>(mutation, variables, "deleteCatalog", ct);
    }
}
