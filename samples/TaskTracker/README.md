# TaskTracker - Azure Stamp Pattern Sample Application

A comprehensive .NET 9 Blazor application demonstrating the Azure Stamp Pattern infrastructure framework with multi-tenancy, task management, and modern cloud-native architecture.

## 🏗️ Architecture Overview

This sample application showcases:

- **Multi-Tenant Architecture**: Complete tenant isolation with data partitioning
- **Azure Stamp Pattern**: Deployed across multiple CELL types for scalability
- **Modern .NET Stack**: Built with .NET 9, Blazor Server, and Bootstrap 5
- **Cloud-Native Services**: Cosmos DB, Blob Storage, Redis, and Container Apps
- **DevOps Ready**: Azure Dev CLI (azd) integration for one-click deployment

## 🚀 Features

### Core Task Management
- ✅ Create, edit, delete, and archive tasks
- 🏷️ Category derived from icon categories; priority levels (High, Medium, Low)
- 📅 Due dates with overdue highlighting
- 🏷️ Tagging system with search functionality
- 👥 Team collaboration within tenants
- 📎 File attachments via Azure Blob Storage
- 🎨 Curated icon/emoji selection

### Multi-Tenancy
- 🏢 Complete tenant isolation
- 🎨 Custom branding per tenant (logos, colors)
- 🔒 Row-level security enforcement
- 🌐 Subdomain routing support
- 👤 Tenant-scoped user management

### Event-Driven Architecture (Dapr)
- 📡 **Event Publishing**: GraphQL mutations publish `task.created`, `task.updated`, `task.deleted` events
- 🎯 **Event Subscribers**: Dedicated controllers handle events for analytics, notifications, and workflows
- 📊 **State Management**: Tenant-scoped statistics and last task caching via Dapr state store
- 🔄 **Pub/Sub**: Redis-backed event streaming with proper tenant isolation
- 🏥 **Health Checks**: Dedicated endpoints for monitoring Dapr service health
- ☁️ **Cloud Ready**: Architecture optimized for Azure Container Apps deployment

### User Experience
- 📱 Responsive design with Bootstrap 5
- 🔍 Advanced search and filtering
- 📊 Task grouping by category
- ⚡ Real-time updates with SignalR
- 🌙 Dark mode support (future)
- ♿ Accessibility compliant

## 🛠️ Technology Stack

| Component | Technology |
|-----------|------------|
| **Frontend** | .NET 9 Blazor Server, Bootstrap 5, Bootstrap Icons |
| **Backend** | ASP.NET Core 9, HotChocolate GraphQL |
| **Database** | Azure Cosmos DB (SQL API) |
| **Storage** | Azure Blob Storage |
| **Cache** | Azure Redis Cache |
| **Event-Driven** | Dapr 1.15.4 (Pub/Sub, State Management) |
| **Auth** | JWT with custom claims |
| **Hosting** | Azure Container Apps |
| **DevOps** | Azure Dev CLI (azd), Docker, Bicep |
| **Observability** | OpenTelemetry (logs/traces/metrics) via OTLP + Collector |

## 🔄 Dapr Event-Driven Architecture

This application implements enterprise-grade event-driven patterns using Dapr (Distributed Application Runtime) for cloud-native scalability and reliability.

### 🎯 Event Publishing (GraphQL Mutations)

All task operations publish events through Dapr's pub/sub component:

```csharp
// Create task event with rich payload
await daprClient.PublishEventAsync("pubsub", "task.created", new
{
    TaskId = task.Id,
    TenantId = task.TenantId,
    Title = task.Title,
    Priority = task.Priority.ToString(),
    CreatedBy = task.CreatedByUserId,
    CreatedAt = task.CreatedAtUtc,
    CategoryId = task.CategoryId,
    DueDate = task.DueDate
});
```

**Published Events:**
- `task.created` - New task creation with full metadata
- `task.updated` - Task modifications with change tracking  
- `task.deleted` - Task deletion with cleanup requirements

### 📡 Event Subscribers (Controllers)

Dedicated Dapr topic subscribers handle events for cross-cutting concerns:

```csharp
[Dapr.Topic("pubsub", "task.created")]
[HttpPost("task-created")]
public async Task<IActionResult> HandleTaskCreated([FromBody] TaskCreatedEvent taskEvent)
{
    // Update tenant statistics
    await _daprStateService.IncrementTaskCountAsync(taskEvent.TenantId);
    
    // Cache last task info
    await _daprStateService.SaveLastTaskAsync(taskEvent.TenantId, taskItem);
    
    // Trigger notifications, analytics, workflows...
    return Ok();
}
```

**Event Handlers:**
- **Analytics**: Track task creation patterns and tenant usage
- **Notifications**: Email/Teams alerts for task assignments
- **Workflows**: Trigger approval processes for high-priority tasks
- **Audit**: Maintain compliance logs for tenant activities

### 🗃️ State Management Service

Structured state management with tenant isolation:

```csharp
public class DaprStateService : IDaprStateService
{
    // Tenant statistics: task counts, completion rates, active users
    Task<TenantStats> GetTenantStatsAsync(string tenantId);
    Task IncrementTaskCountAsync(string tenantId);
    
    // Last task caching for dashboard widgets
    Task SaveLastTaskAsync(string tenantId, TaskItem task);
    Task<LastTaskInfo> GetLastTaskAsync(string tenantId);
}
```

**State Patterns:**
- **Tenant Statistics**: `tenant-{id}-stats` → task counts, metrics
- **Last Task Cache**: `tenant-{id}-last-task` → recent task info
- **User Sessions**: `tenant-{id}-user-{userId}` → user state

### 🏗️ Dapr Components Configuration

**Redis Pub/Sub** (`dapr/components/pubsub.yaml`):
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub
spec:
  type: pubsub.redis
  metadata:
  - name: redisHost
    value: redis:6379
  - name: redisDB
    value: "0"  # Dedicated DB for pub/sub
```

**Redis State Store** (`dapr/components/statestore.yaml`):
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: statestore
spec:
  type: state.redis
  metadata:
  - name: redisHost
    value: redis:6379
  - name: redisDB
    value: "1"  # Dedicated DB for state
```

### 🐳 Docker Deployment

**Standard Deployment**:
```bash
docker-compose up -d  # App + databases (no Dapr)
```

**Enhanced Dapr Deployment**:
```bash
docker-compose -f docker-compose.dapr.yml up -d
```

The Dapr configuration includes:
- **Placement Service**: Dapr actor placement
- **Sidecar Container**: Handles all Dapr communication
- **Component Mounting**: Redis pub/sub and state store
- **Health Monitoring**: `/api/dapr/health` endpoint

### 🔍 Testing Dapr Integration

**Event Publishing Test**:
```bash
curl -X POST http://localhost:8080/api/dapr/task-created \
  -H "Content-Type: application/json" \
  -d '{"id":"550e8400-e29b-41d4-a716-446655440000","tenantId":"tenant-fabrikam","title":"Test Task"}'
```

**State Management Test**:
```bash
curl http://localhost:8080/api/dapr/tenant/tenant-fabrikam/stats
# Response: {"tenantId":"tenant-fabrikam","totalTasks":1,"completedTasks":0,"activeUsers":0}
```

**Health Check**:
```bash
curl http://localhost:8080/api/dapr/health
# Response: {"status":"healthy","timestamp":"2025-09-03T17:36:21Z"}
```

### ☁️ Azure Container Apps Integration

The Dapr configuration is optimized for seamless Azure deployment:

- **Managed Dapr**: Azure Container Apps provides Dapr runtime
- **Component Binding**: Redis/Service Bus automatic configuration  
- **Scaling**: Event-driven autoscaling based on pub/sub queue depth
- **Monitoring**: Integration with Application Insights and Log Analytics
- **Security**: Managed identities for secure component access

This architecture provides robust event-driven capabilities while maintaining simplicity for local development and powerful scalability for cloud deployment.

## 🏃‍♂️ Quick Start

### Prerequisites

- [.NET 9 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Azure Developer CLI](https://docs.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [Visual Studio 2022](https://visualstudio.microsoft.com/) or [VS Code](https://code.visualstudio.com/)

### Local Development

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd tasktracker-stamp-pattern
   ```

2. **Start local services**
   
   **Option A - Standard Development** (databases only):
   ```bash
   docker compose up -d
   ```
   This starts Cosmos DB Emulator, Azurite (Blob Storage), and Redis.

   **Option B - Enhanced with Dapr** (recommended for full testing):
   ```bash
   docker compose -f docker-compose.dapr.yml up -d
   ```
   This includes all services plus Dapr sidecars for event-driven features.

3. **Run the application**
  - Option A (containerized, default): The app runs inside Docker. Find the mapped port and browse:
    ```powershell
    docker compose ps
    ```
    Open `http://localhost:<PORT>/` and GraphQL Playground at `http://localhost:<PORT>/graphql`.
  - Option B (run locally): Start dependencies with Docker, then run the app locally:
    ```bash
    dotnet run
    ```

4. **Access the application**
  - App: `http://localhost:<PORT>/`
  - GraphQL: `http://localhost:<PORT>/graphql`
  - Health: `http://localhost:<PORT>/health`
  - Dapr health (when using Dapr compose): `http://localhost:8080/api/dapr/health`
  - Dev-only (HTML or JSON; add `?format=html` or `?format=json`):
    - `http://localhost:<PORT>/dev/seed-status` — shows current seed counts in Cosmos (dev)
    - `http://localhost:<PORT>/dev/init-cosmos` — creates DB/containers if missing; safe to re-run (dev)
    - `http://localhost:<PORT>/dev/seed-json` — seeds from JSON fixtures under `seed/` (dev)
  - Use demo credentials:
## 🌱 Seed Data (development)

This sample provides optional demo seed data to make first run useful in local/dev environments.

Recommended: Seed using JSON fixtures (no rebuild needed):
- Place JSON files (tenants.json, users.json, categories.json, tags.json, tasks.json, settings.json) under `seed/` (mounted at `/app/seed`).
- Call `POST /dev/seed-json` to load data idempotently using the Cosmos SDK.
- Override the folder via env `Seed__JsonPath` (defaults to `/app/seed`).

Note: JSON fixtures are the single supported seeding method. Legacy GraphQL/file-based and code-based seeders were removed for simplicity.

- Flags controlling initialization and seeding (read from configuration/environment):
  - `SkipCosmosInit`: when true, skips Cosmos container creation and seeding. Default: false in Compose.
  - `SeedOnStartup`: when true, seeds after containers are created. Default: true in Compose.
- In `docker-compose.yml` under the `tasktracker` service:
  - `SkipCosmosInit: "false"`
  - `SeedOnStartup: "true"`

Seeded content per tenant (default fixtures):
- Tenants: `tenant-contoso`, `tenant-fabrikam`, `tenant-adventure-works`
- Users: 1–2+ demo users per tenant (e.g., john.doe@contoso.com)
- Workflow stages: Backlog, In Progress, Code Review, Testing, Blocked, Done
- Tags: backend, frontend, api, bug, feature, urgent, docs, infra
- Tasks: a realistic set with varied priorities, due dates, categories, assignees, and tag names

Notes:
- On first launch the Cosmos DB Emulator can take ~15–30s to warm up; the app retries init. Refresh the page after a short wait.
- The demo `AuthenticationService` defaults the current tenant to `tenant-contoso`, so the Home page shows seeded data by default.
- To disable seeding, set `SeedOnStartup` to `false` or set `SkipCosmosInit` to `true`.

Dev endpoints workflow (if you see NotFound errors):
- Visit `/dev/init-cosmos` first to ensure the database/containers exist (supports `?format=html` for a readable page).
- Then call `POST /dev/seed-json` to seed from fixtures.
- Finally, check `/dev/seed-status` (use `?format=html` or `?format=json`). If it still shows NotFound, wait a few seconds and refresh; the emulator may still be warming up.

Category behavior:
- The app’s visible "Category" comes from the selected icon’s category. Filters and grouping on the Home page use these icon categories. Seeded tasks include a variety of icons across categories to demonstrate this.

### 🔁 How to reseed

Option A — reset the emulator volume (wipes all local data):

```powershell
# Stop stack
docker compose -f .\docker-compose.yml down

# Remove the emulator data volume defined in docker-compose (cosmosdb-data)
docker volume rm tasktracker-stamppattern_cosmosdb-data

# Start fresh; containers will recreate DB/containers and seed
docker compose -f .\docker-compose.yml up -d --build tasktracker
```

Option B — use a new database name (keeps existing data intact):

1) In `appsettings.Development.json`, change `CosmosDb:DatabaseName` to a new value (e.g., `TaskTrackerDb_dev2`).
2) Ensure `SkipCosmosInit=false` and `SeedOnStartup=true` (Compose already sets these), then restart the app container.

Optional verification (dev-only):
- `GET /dev/seed-status` to see item counts
     - **john.doe@contoso.com** / **demo123** (Contoso North)
     - **jane.smith@fabrikam.com** / **demo123** (Fabrikam Corp)
     - **admin@adventure-works.com** / **demo123** (Adventure Works)

### Azure Deployment

1. **Initialize azd**
   ```bash
   azd init
   ```

2. **Deploy to Azure**
   ```bash
   azd up
   ```

3. **Access your deployed app**
   ```bash
   azd browse
   ```

## 📁 Project Structure

```
TaskTracker.Blazor/
├── _Imports.razor
├── Components/
│   ├── Layout/
│   │   └── MainLayout.razor
│   ├── Pages/
│   │   ├── Home.razor
│   │   ├── Login.razor
│   │   └── EditTask.razor
│   └── Shared/
│       ├── TaskCard.razor
│       ├── NewTaskModal.razor
│       ├── ConfirmDialog.razor
│       └── RedirectToLogin.razor
├── Controllers/
│   └── DaprController.cs      # Event subscribers & health checks
├── Pages/
│   ├── _Host.cshtml
│   └── Shared/
│       └── _Layout.cshtml
├── Models/
│   ├── Task.cs
│   ├── Category.cs
│   └── Tenant.cs
├── Services/
│   ├── CosmosDbService.cs
│   ├── BlobStorageService.cs
│   ├── DaprStateService.cs    # Dapr state management
│   └── IconService.cs
├── GraphQL/
│   ├── Query.cs
│   └── Mutation.cs            # Enhanced with Dapr event publishing
├── wwwroot/
│   ├── css/
│   │   └── site.css
│   └── js/
│       └── bootstrapInterop.js
├── dapr/
│   └── components/
│       ├── pubsub.yaml        # Redis pub/sub component
│       └── statestore.yaml    # Redis state store component
├── docs/
│   ├── API_DOCUMENTATION.md
│   └── DAL_OVERVIEW.md
├── infra/
│   └── main.bicep             # Bicep infrastructure templates
├── docker-compose.yml         # Standard local development
├── docker-compose.dapr.yml    # Enhanced with Dapr sidecars
├── Dockerfile                 # Container definition
├── azure.yaml                 # Azure Dev CLI configuration
├── TaskTracker.Blazor.csproj
└── README.md
```

## 🎯 Multi-Tenant Demo Scenarios

The application includes pre-configured demo tenants:

### Contoso North (`tenant-contoso`)
- **Users**: john.doe@contoso.com, alice.johnson@contoso.com
- **Domain**: contoso.com
- **Brand Color**: #0078d4 (Microsoft Blue)
- **Use Case**: Enterprise software development team

### Fabrikam Corp (`tenant-fabrikam`)
- **Users**: jane.smith@fabrikam.com, bob.wilson@fabrikam.com
- **Domain**: fabrikam.com
- **Brand Color**: #107c10 (Success Green)
- **Use Case**: Marketing and design agency

### Adventure Works (`tenant-adventure-works`)
- **Users**: admin@adventure-works.com
- **Domain**: adventure-works.com
- **Brand Color**: #d83b01 (Orange)
- **Use Case**: Retail operations team

## 🔧 Configuration

### Local Development (appsettings.Development.json)

```json
{
  "ConnectionStrings": {
    "CosmosDb": "AccountEndpoint=https://localhost:8081/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==",
    "BlobStorage": "UseDevelopmentStorage=true",
    "Redis": "localhost:6379"
  },
  "CosmosDb": {
    "DatabaseName": "TaskTrackerDb"
  },
  "BlobStorage": {
    "ContainerName": "task-attachments"
  },
  "Jwt": {
    "SecretKey": "your-secret-key-here-make-it-long-enough-for-security",
    "Issuer": "TaskTracker",
    "Audience": "TaskTracker"
  }
}
```

This app uses the Options pattern with validation:
- Cosmos options: `ConnectionStrings:CosmosDb` and `CosmosDb:DatabaseName` (required; default `TaskTrackerDb`)
- Blob options: `ConnectionStrings:BlobStorage` and `BlobStorage:ContainerName` (required; default `task-attachments`)
- Redis options: `ConnectionStrings:Redis` (optional; in-memory cache if empty)

Standardized errors are enabled via ProblemDetails. Requests/Responses include an `x-correlation-id` header (generated if not provided) for end-to-end tracing.

### Production (Azure App Service / Container Apps)

Environment variables are automatically configured through Bicep templates:

- `COSMOSDB_CONNECTION_STRING`
- `STORAGE_CONNECTION_STRING`
- `REDIS_CONNECTION_STRING`
- `APPLICATIONINSIGHTS_CONNECTION_STRING`

OpenTelemetry is enabled by default (ASP.NET Core, HttpClient, runtime metrics) and exports to the OTEL Collector in Compose via OTLP. Adjust `otel/otel-collector-config.yaml` to change exporters (e.g., file, console). Set `OTEL_SERVICE_NAME` and `OTEL_EXPORTER_OTLP_ENDPOINT` via environment.

## 🧪 Testing the Application

### Task Management Workflow

1. **Login** with a demo account
2. **Create tasks** with different priorities and categories
3. **Add tags** and **assign to team members**
4. **Upload attachments** to test blob storage integration
5. **Filter and search** tasks by various criteria
6. **Archive completed tasks**
7. **Switch tenants** to see data isolation

### Multi-Tenancy Validation

1. Login as users from different tenants
2. Verify complete data isolation
3. Confirm tenant-specific branding
4. Test cross-tenant access restrictions

## 🔐 Security Features

- **Authentication**: JWT-based with custom claims
- **Authorization**: Tenant-scoped data access
- **Data Isolation**: Partition key-based isolation in Cosmos DB
- **Secure File Upload**: Time-limited SAS tokens for blob storage
- **HTTPS Enforcement**: All communication encrypted
- **Input Validation**: Client and server-side validation

## 📊 Monitoring and Observability

- **Application Insights**: Performance monitoring and telemetry
- **Log Analytics**: Centralized logging
- **Health Checks**: Application health monitoring
- **Metrics**: Custom metrics for tenant usage

## 🎨 Customization

### Adding New Tenants

1. Update `seed/tenants.json` (and `seed/users.json` as needed)
2. Optionally add `seed/settings.json` for branding defaults
3. Run `POST /dev/seed-json`
4. Configure domain mapping in `appsettings.json` if using subdomains

### Extending Task Features

1. Add properties to the `TaskItem` model
2. Update Cosmos DB schema
3. Modify UI components
4. Update validation rules

### Custom Icons

Add new icons to `IconService.cs`:

```csharp
["custom.key"] = new() { 
    Key = "custom.key", 
    Glyph = "🎯", 
    Tooltip = "Custom Icon", 
    Category = "Custom" 
}
```

## 🚀 Deployment Options

### Development
- Local with Docker Compose
- Cosmos DB Emulator + Azurite + Redis

### Staging/Production
- Azure Container Apps
- Azure Cosmos DB
- Azure Blob Storage
- Azure Redis Cache
- Azure Application Insights

## 📝 API Endpoints

### Core Application
- `POST/GET /graphql` — GraphQL API (queries, mutations, subscriptions). See `API_DOCUMENTATION.md`.
- `POST /api/upload/sas` — Generate SAS token for file upload.
  - Note: This endpoint is rate-limited to 60 requests/minute (HTTP 429 on limit).
- `GET /health` — Application health endpoint.
  - `GET /readyz` — Readiness health checks (Cosmos, Blob, optional Redis)
  - `GET /healthz` — Aggregate health checks

### Dapr Event-Driven Endpoints  
- `POST /api/dapr/task-created` — Handle task.created events (Dapr topic subscriber)
- `GET /api/dapr/tenant/{tenantId}/stats` — Get tenant statistics from Dapr state store
- `GET /api/dapr/health` — Dapr service health check

### Development Endpoints
- `GET /dev/seed-status` — Development-only seed verification.
- `GET /dev/init-cosmos` — Initialize Cosmos DB resources (dev-only).
- `POST /dev/seed-json` — Seed from JSON fixtures under `seed/` (dev-only).
  Note: JSON fixtures are the only supported seeding path.

This project includes a built-in GraphQL server (HotChocolate) exposed at `/graphql`. Refer to `docs/API_DOCUMENTATION.md` for queries, mutations, subscriptions, authentication, and examples. See `docs/DAL_OVERVIEW.md` for the current DAL architecture and components.

## 🧭 Error Handling & Correlation

- The API returns RFC 7807 ProblemDetails for errors (validation, 4xx/5xx), with fields like `type`, `title`, `status`, `detail`, and `extensions`.
- Clients can provide `x-correlation-id`; if omitted, the server returns a generated value in the response headers. Include this in logs/bug reports.

## 📈 Observability (OpenTelemetry)

- Traces, metrics, and logs are emitted via OpenTelemetry and exported to the local Collector (see `otel-collector` service in Compose).
- Default exporter: logging (in Collector), OTLP from app. You can switch/add exporters (e.g., OTLP to an external backend) by editing `otel/otel-collector-config.yaml`.
- Health endpoints (`/health`, `/readyz`, `/healthz`) are excluded from tracing to reduce noise.

## 🎯 Performance Considerations

### Database Optimization
- **Partition Strategy**: All queries scoped by `tenantId`
- **Indexing**: Optimized for common query patterns
- **Request Units**: Auto-scaling based on demand
- **Connection Pooling**: Efficient connection management

### Caching Strategy
- **Redis**: Session state and frequently accessed data
- **Browser Cache**: Static assets with proper cache headers
- **CDN**: Global distribution of static content (future)

### Scalability
- **Horizontal Scaling**: Container Apps auto-scale
- **Database Scaling**: Cosmos DB auto-scale
- **Storage**: Unlimited blob storage capacity
- **Multi-Region**: Deploy to multiple Azure regions

## 🧪 Testing Strategy

### Unit Tests
```bash
dotnet test --logger "trx;LogFileName=TestResults.xml"
```

### Integration Tests
```bash
# Start test services
docker-compose -f docker-compose.test.yml up -d

# Run integration tests
dotnet test --configuration Release --logger "trx;LogFileName=IntegrationTests.xml"
```

### Load Testing
```bash
# Using Azure Load Testing service
az load test create --name "tasktracker-load-test" \
  --resource-group "rg-tasktracker" \
  --test-plan-file "loadtest.jmx"
```

## 🔧 Troubleshooting

### Common Issues

#### Cosmos DB Connection Failed
```bash
# Check if emulator is running
docker ps | grep cosmos

# Restart emulator
docker-compose restart cosmosdb
```

#### Blob Storage Access Denied
```bash
# Verify Azurite is running
docker ps | grep azurite

# Check connection string
echo $AZURE_STORAGE_CONNECTION_STRING
```

#### Dapr Event Publishing Issues
```bash
# Check Dapr sidecar is running
docker ps | grep dapr

# Test Dapr health directly
curl http://localhost:8080/api/dapr/health

# Check Redis pub/sub connectivity
docker logs tasktracker-stamppattern-tasktracker-dapr-1

# Restart with Dapr components
docker-compose -f docker-compose.dapr.yml down
docker-compose -f docker-compose.dapr.yml up -d
```

#### Authentication Issues
```bash
# Clear browser storage
# Check JWT secret key configuration
# Verify token expiration
```

### Debug Logging

Enable detailed logging in `appsettings.Development.json`:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft.AspNetCore": "Information",
      "TaskTracker.Blazor": "Debug"
    }
  }
}
```

## 🤝 Contributing

### Development Workflow

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** changes: `git commit -m 'Add amazing feature'`
4. **Push** to branch: `git push origin feature/amazing-feature`
5. **Submit** a Pull Request

### Code Standards

- Follow [C# Coding Conventions](https://docs.microsoft.com/en-us/dotnet/csharp/programming-guide/inside-a-program/coding-conventions)
- Use [EditorConfig](https://editorconfig.org/) for consistent formatting
- Add XML documentation for public APIs
- Write unit tests for new features
- Update README for significant changes

### Pull Request Checklist

- [ ] Code builds without errors or warnings
- [ ] All tests pass
- [ ] Documentation updated
- [ ] No breaking changes (or properly documented)
- [ ] Security implications reviewed

## 📚 Additional Resources

### Microsoft Documentation
- [Azure Stamp Pattern](https://docs.microsoft.com/azure/architecture/patterns/stamp)
- [Azure Container Apps](https://docs.microsoft.com/azure/container-apps/)
- [Cosmos DB Multi-Tenancy](https://docs.microsoft.com/azure/cosmos-db/multi-tenant-applications)
- [.NET 9 Features](https://docs.microsoft.com/dotnet/core/whats-new/dotnet-9)

### Related Samples
- [Azure Architecture Center](https://docs.microsoft.com/azure/architecture/)
- [Azure Dev CLI Templates](https://azure.github.io/awesome-azd/)
- [Multi-Tenant SaaS Samples](https://github.com/Azure/azure-saas-samples)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Azure Stamp Pattern Team** for the architectural guidance
- **Microsoft Azure** for the cloud services
- **.NET Community** for the amazing framework
- **Bootstrap Team** for the UI components
- **Open Source Contributors** for the dependencies

---

## 🚀 Next Steps

After exploring this sample application, consider:

1. **Extend Features**: Add real-time notifications, advanced analytics, or mobile apps
2. **Scale Up**: Deploy to multiple regions with Azure Front Door
3. **Enterprise Integration**: Connect to Azure AD, Microsoft Graph, or other services
4. **Advanced Monitoring**: Implement custom dashboards and alerting
5. **CI/CD Pipeline**: Set up GitHub Actions or Azure DevOps pipelines

For questions, issues, or feature requests, please open an issue in the repository.

Happy coding! 🎉