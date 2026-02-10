# Error Handling — Instructions

applyTo: "AzureArchitecture/**/*.cs,management-portal/src/**/*.cs"

## Error Handling Strategy

All error handling follows a **defense-in-depth** pattern: catch specific exceptions first, then general exceptions, and always return appropriate HTTP status codes.

### Function-Level Pattern

Every Azure Function should follow this structure:

```csharp
[Function("FunctionName")]
public async Task<HttpResponseData> Run(
    [HttpTrigger(AuthorizationLevel.Function, "post", Route = "...")] HttpRequestData req)
{
    try
    {
        // 1. Input validation — return 400
        var input = await req.ReadFromJsonAsync<RequestModel>();
        if (input == null || string.IsNullOrEmpty(input.RequiredField))
        {
            var badRequest = req.CreateResponse(HttpStatusCode.BadRequest);
            await badRequest.WriteStringAsync("RequiredField is required.");
            return badRequest;
        }

        // 2. Business logic
        var result = await ProcessAsync(input);

        // 3. Success response
        var response = req.CreateResponse(HttpStatusCode.OK);
        await response.WriteAsJsonAsync(result);
        return response;
    }
    catch (JsonException ex)
    {
        // Invalid JSON payload
        _logger.LogError(ex, "Invalid JSON in request body");
        var error = req.CreateResponse(HttpStatusCode.BadRequest);
        await error.WriteStringAsync("Invalid JSON format in request body.");
        return error;
    }
    catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
    {
        // Resource not found
        _logger.LogWarning("Resource not found: {Message}", ex.Message);
        var error = req.CreateResponse(HttpStatusCode.NotFound);
        await error.WriteStringAsync("Resource not found.");
        return error;
    }
    catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
    {
        // Duplicate resource
        _logger.LogWarning("Conflict: {Message}", ex.Message);
        var error = req.CreateResponse(HttpStatusCode.Conflict);
        await error.WriteStringAsync("Resource already exists.");
        return error;
    }
    catch (CosmosException ex)
    {
        // Other Cosmos errors
        _logger.LogError(ex, "Cosmos DB error during operation");
        var error = req.CreateResponse(HttpStatusCode.InternalServerError);
        await error.WriteStringAsync("Database error occurred. Please try again.");
        return error;
    }
    catch (Exception ex)
    {
        // Unexpected errors
        _logger.LogError(ex, "Unexpected error during operation");
        var error = req.CreateResponse(HttpStatusCode.InternalServerError);
        await error.WriteStringAsync("An unexpected error occurred. Please contact support.");
        return error;
    }
}
```

### Exception Hierarchy (catch order)

1. `JsonException` → 400 Bad Request
2. `CosmosException` (NotFound) → 404 Not Found
3. `CosmosException` (Conflict) → 409 Conflict
4. `CosmosException` (other) → 500 Internal Server Error
5. `InvalidOperationException` → 400 or 500 depending on context
6. `Exception` (catch-all) → 500 Internal Server Error

### Client-Facing Error Messages

- **Never expose** internal details, stack traces, connection strings, or database names
- Use generic messages: "Database error occurred", "An unexpected error occurred"
- For validation: be specific about what's missing ("TenantId and Subdomain are required")

### Server-Side Logging

- **Always log** the full exception with structured parameters
- Include context: tenant ID, operation name, correlation ID
- Use appropriate log levels:

```csharp
_logger.LogWarning("Validation failed for tenant {TenantId}: {Reason}", tenantId, reason);
_logger.LogError(ex, "Cosmos DB error during CELL assignment for tenant {TenantId}", tenantId);
_logger.LogError(ex, "Unexpected error during tenant creation");
```

### Non-Critical Failures (Graceful Degradation)

For operations where failure is acceptable (caching, metrics, etc.):

```csharp
try
{
    await _cache.SetStringAsync(key, value, options);
}
catch (Exception ex)
{
    _logger.LogError(ex, "Cache write failed for {Key}", key);
    // Don't throw — caching is not critical
}
```

Apply this pattern to:
- Cache reads/writes (fall back to database)
- Metrics recording (log and continue)
- Background refresh scheduling
- Non-essential logging operations

### Result Pattern

For internal methods, use result objects instead of exceptions:

```csharp
public class CellAssignmentResult
{
    public bool Success { get; set; }
    public string CellBackendPool { get; set; }
    public string ErrorMessage { get; set; }
    public string AssignmentReason { get; set; }
}
```

- Check `result.Success` before proceeding
- Include `ErrorMessage` for diagnostics
- Return appropriate HTTP status based on result

### Retry Configuration

- Function-level: host.json exponential backoff (3 retries, 5s–5m interval)
- Cosmos DB: SDK-level retry (3 attempts, 30s max wait for rate limiting)
- Deployment scripts: custom retry helpers with exponential backoff
- Cache: no retries — fail fast and degrade gracefully
