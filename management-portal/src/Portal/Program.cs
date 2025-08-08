using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using ServiceDefaults;

var builder = WebApplication.CreateBuilder(args);
builder.AddServiceDefaults("Stamps.ManagementPortal");

builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();
builder.Services.AddHttpClient("GraphQL", (sp, client) =>
{
    var cfg = sp.GetRequiredService<IConfiguration>();
    var baseUrl = cfg["DAB_GRAPHQL_URL"] ?? "";
    if (!string.IsNullOrWhiteSpace(baseUrl))
    {
        client.BaseAddress = new Uri(baseUrl);
    }
});

var useGraphQL = !string.IsNullOrWhiteSpace(builder.Configuration["DAB_GRAPHQL_URL"]);
if (useGraphQL)
{
    builder.Services.AddSingleton<Stamps.ManagementPortal.Services.IDataService, Stamps.ManagementPortal.Services.GraphQLDataService>();
}
else
{
    builder.Services.AddSingleton<Stamps.ManagementPortal.Services.IDataService, Stamps.ManagementPortal.Services.InMemoryDataService>();
}

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();

app.MapBlazorHub();
app.MapFallbackToPage("/_Host");
app.MapHealthChecks("/health");

app.Run();
