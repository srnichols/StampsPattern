# Blazor Server — Instructions

applyTo: "management-portal/**/*.razor,management-portal/**/*.cs,management-portal/**/*.cshtml"

## Framework & Hosting

- **Blazor Server** (.NET 7+ via Portal.csproj) — NOT Blazor WebAssembly
- Server-side rendering with SignalR circuits
- Hosted on Azure Container Apps via `azd` deployment
- Uses Microsoft Identity Web for Entra ID authentication

## Project Structure

```
management-portal/src/Portal/
├── Pages/              # Routable Razor components (@page directive)
│   ├── Index.razor
│   ├── Tenants.razor
│   ├── Cells.razor
│   ├── CellManagement.razor
│   ├── TenantOnboarding.razor
│   ├── Configuration.razor
│   ├── Deployment.razor
│   ├── Infrastructure.razor
│   └── Operations.razor
├── Shared/             # Layout and shared UI components
│   ├── MainLayout.razor
│   └── NavMenu.razor
├── GraphQL/            # Hot Chocolate GraphQL (Query, Mutation, Subscription)
├── Services/           # Data access layer (IDataService implementations)
├── Models/             # Portal-specific data models
├── wwwroot/            # Static assets (CSS, JS, images)
├── Program.cs          # DI, middleware, auth configuration
└── Dockerfile          # Container build definition
```

## Component Conventions

### Page Components

- Every page MUST have a `@page "/route"` directive
- Inject services via `@inject` — never use `new` for service instantiation
- Use `@inject IDataService Data` for all data operations
- Use `@inject IJSRuntime JSRuntime` for JavaScript interop (sparingly)
- Use `@inject ILogger<ComponentName> Logger` for logging

### Component Naming

| Type | Pattern | Example |
|------|---------|---------|
| Page | `{Domain}.razor` | `Tenants.razor`, `Cells.razor` |
| Shared | `{Purpose}.razor` | `MainLayout.razor`, `NavMenu.razor` |
| Partial class | `{Component}.razor.cs` | `Tenants.razor.cs` |

### Component Structure (within `.razor` file)

```razor
@page "/route"
@using statements
@inject statements

<!-- HTML/Razor markup -->

@code {
    // 1. Parameters and cascading values
    // 2. Injected service fields (if using partial class)
    // 3. Private fields and properties
    // 4. Lifecycle methods (OnInitializedAsync, OnParametersSetAsync)
    // 5. Event handlers
    // 6. Private helper methods
}
```

## Data Access Pattern

### IDataService Abstraction

ALL data access goes through `IDataService`. Never bypass it.

```csharp
// ✅ Correct — use the abstraction
@inject Stamps.ManagementPortal.Services.IDataService Data

var tenants = await Data.GetTenantsAsync();

// ❌ Wrong — never inject Cosmos/SQL clients directly in components
@inject CosmosClient _cosmos  // NEVER
```

### Available IDataService Implementations

| Implementation | When Used | Description |
|---------------|-----------|-------------|
| `InMemoryDataService` | Development / Demo | In-memory seed data, no external deps |
| `GraphQLDataService` | Production | Calls Hot Chocolate GraphQL backend |
| `CosmosDiscoveryService` | Production | Direct Cosmos DB for discovery data |
| `DaprDataService` | Dapr-enabled environments | Uses Dapr state management |

### Configure via `appsettings.json`

```json
{
  "DataSource": "InMemory"  // or "GraphQL", "Cosmos", "Dapr"
}
```

## Forms & Validation

- Use `<EditForm>` with `<DataAnnotationsValidator />` for all forms
- Use `<ValidationMessage For="..." />` for field-level errors
- Use `<ValidationSummary />` for form-level error summaries
- Bind with `@bind-Value` (two-way binding)
- Handle submit via `OnValidSubmit` callback

```razor
<EditForm Model="editModel" OnValidSubmit="OnSaveAsync">
    <DataAnnotationsValidator />
    <div class="form-group mb-3">
        <label class="form-label">Tenant ID</label>
        <InputText @bind-Value="editModel.Id" class="form-control" />
        <ValidationMessage For="@(() => editModel.Id)" />
    </div>
    <button type="submit" class="btn btn-primary">Save</button>
</EditForm>
```

## UI Framework & Styling

- **Bootstrap 5** for layout and components
- **Bootstrap Icons** (`bi bi-*`) for iconography
- Scoped CSS via `{Component}.razor.css` when component-specific styles are needed
- Global styles in `wwwroot/css/`
- Use Bootstrap utility classes over custom CSS when possible

### Layout Convention

- Fixed sidebar (280px) with `NavMenu` component
- Top navbar with version badge, data source indicator, and GitHub link
- Main content area with `#f8f9fa` background
- Responsive breakpoint at 768px

## Authentication & Authorization

- Uses **Microsoft Identity Web** with OpenID Connect (Entra ID)
- Configured in `Program.cs` via `AddMicrosoftIdentityWebApp`
- Role-based policies: `admin`, `operator`

```csharp
// Program.cs pattern
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("admin", policy => policy.RequireRole("admin"));
    options.AddPolicy("operator", policy => policy.RequireRole("operator"));
});
```

- Protect pages with `[Authorize]` attribute or `@attribute [Authorize(Policy = "admin")]`
- Always check authorization before destructive operations (delete, migrate)

## GraphQL Integration (Hot Chocolate)

The portal includes a Hot Chocolate GraphQL endpoint for rich data queries:

### Schema Convention

- `Query.cs` — read operations (tenants, cells, operations)
- `Mutation.cs` — write operations (create, update, delete)
- `Subscription.cs` — real-time updates via GraphQL subscriptions

### Usage from Components

```csharp
// GraphQLDataService handles the HTTP calls to /graphql
// Components should only use IDataService, never call GraphQL directly
```

## Error Handling in Components

```razor
@code {
    private string? errorMessage;
    private bool isLoading = true;

    protected override async Task OnInitializedAsync()
    {
        try
        {
            isLoading = true;
            await LoadDataAsync();
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "Failed to load data");
            errorMessage = "Unable to load data. Please try again.";
        }
        finally
        {
            isLoading = false;
        }
    }
}
```

- Show loading indicators during async operations
- Display user-friendly error messages (never raw exceptions)
- Log full exceptions server-side via `ILogger`

## Performance Guidelines

- Use `@key` directive on list items for efficient diffing
- Prefer `OnInitializedAsync` over `OnParametersSetAsync` for initial data load
- Avoid calling `StateHasChanged()` redundantly (Blazor calls it after event handlers)
- Use `CancellationToken` in long-running operations
- Minimize JS interop calls — prefer C# solutions

## Deployment

- Containerized via `Dockerfile` in the Portal project
- Deployed to Azure Container Apps via `azd up`
- See `azure.yaml` in repo root for service definitions
- Environment-specific settings via `appsettings.Production.json`
