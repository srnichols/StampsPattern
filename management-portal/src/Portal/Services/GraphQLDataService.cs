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
}
