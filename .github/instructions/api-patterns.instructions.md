# API Patterns — Instructions

applyTo: "AzureArchitecture/**/*Function.cs,AzureArchitecture/DocumentationFunction.cs,AzureArchitecture/host.json"

## API Design

All APIs are Azure Functions HTTP triggers following RESTful conventions.

### Endpoint Catalog

| Function | Method | Route | Auth | Purpose |
|----------|--------|-------|------|---------|
| `CreateTenant` | POST | `/api/tenant` | Function | Create a new tenant |
| `GetTenantCell` | GET | `/api/tenant/{subdomain}` | Function | Look up tenant routing by subdomain |
| `GetTenantInfo` | GET | `/api/tenant/{tenantId}` | Anonymous + JWT | Get full tenant info (JWT validated in code) |
| `AddUserToTenant` | POST | `/api/tenant/{tenantId}/user` | Function | Add user to a tenant |
| `MigrateTenant` | POST | `/api/tenant/{tenantId}/migrate` | Function | Migrate tenant between CELLs |
| `GetCellCapacity` | GET | `/api/cells/capacity?region=&cellType=` | Function | Query CELL capacity |
| `ProvisionCell` | POST | `/api/cells/provision` | Function | Manually provision a new CELL |
| `GetCellAnalytics` | GET | `/api/cells/analytics` | Function | Comprehensive capacity analytics |
| `MonitorCellCapacityNow` | POST | `/api/cells/capacity/run` | Function | Trigger capacity monitoring |
| `DiscoverInfrastructure` | GET/POST | `/api/infrastructure/discover?mode=` | Function | Infrastructure discovery |
| `HealthCheck` | GET | `/api/health` | Anonymous | Service health status |
| `SwaggerUI` | GET | `/api/swagger/ui` | Anonymous | API documentation |

### Request/Response Patterns

**Request deserialization:**

```csharp
var tenant = await req.ReadFromJsonAsync<TenantInfo>();
```

**Success responses:**

```csharp
var response = req.CreateResponse(HttpStatusCode.Created); // 201 for creates
await response.WriteAsJsonAsync(tenant);
return response;
```

**Error responses:**

```csharp
var errorResponse = req.CreateResponse(HttpStatusCode.BadRequest); // 400, 404, 500
await errorResponse.WriteStringAsync("Human-readable error message.");
return errorResponse;
```

### HTTP Status Code Convention

| Code | When |
|------|------|
| 200 OK | Successful read or update |
| 201 Created | Successful resource creation |
| 202 Accepted | Async operation triggered (capacity monitoring) |
| 400 Bad Request | Missing required fields, invalid JSON, validation failure |
| 401 Unauthorized | Missing or invalid JWT token |
| 404 Not Found | Tenant or CELL not found |
| 500 Internal Server Error | Database errors, unexpected exceptions |

### Query Parameter Patterns

- Use `req.Query["paramName"]` for optional filters
- Validate enum values with `Enum.TryParse<T>()`
- Support filtering by `region`, `cellType`, `status`

### Route Configuration

```json
// host.json
{
  "extensions": {
    "http": {
      "routePrefix": "api",
      "maxOutstandingRequests": 200,
      "maxConcurrentRequests": 100,
      "dynamicThrottlesEnabled": true
    }
  }
}
```

### OpenAPI Documentation

- Use `[OpenApiOperation]` attributes on documentation/health endpoints
- Swagger UI served at `/api/swagger/ui`
- OpenAPI spec at `/api/swagger.json`
- Include operation tags, summary, and response types

### Function Timeout & Retry

```json
// host.json
{
  "functionTimeout": "00:05:00",
  "retry": {
    "strategy": "exponentialBackoff",
    "maxRetryCount": 3,
    "minimumInterval": "00:00:05",
    "maximumInterval": "00:05:00"
  }
}
```

### Concurrency Control

- Dynamic concurrency enabled with snapshot persistence
- Health monitor: 30s check interval, 2-minute window, 80% threshold
- These settings are in `host.json` — do not override per-function
