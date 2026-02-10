# AI Agents & Copilot — Instructions

applyTo: "**/*"

## Purpose

This file governs how AI coding agents (GitHub Copilot, Copilot Chat, MCP-based agents) should interact with, reason about, and generate code for the Azure Stamps Pattern (ASPA) solution. These rules ensure consistent, architecture-aware assistance.

## Agent Behavioral Rules

### 1. Domain Awareness

Agents operating in this codebase MUST understand the core domain model:

- **CELL** = a deployment stamp. Shared CELLs host 10–100 tenants; Dedicated CELLs host 1 enterprise tenant.
- **Hierarchy**: GEO → Region → Availability Zone → CELL
- **TenantTier**: `Startup`, `SMB`, `Shared`, `Enterprise`, `Dedicated`
- **CellType**: `Shared`, `Dedicated`
- **TenantStatus lifecycle**: `Active` → `Inactive` → `Suspended` → `Migrating` → `Provisioning` → `Deprovisioning`
- Cosmos DB `globaldb` is the control plane data store (containers: `tenants`, `cells`, `tenantUsers`)
- Partition key for tenants = `tenantId`, for cells = `cellId`

### 2. Architecture-Aware Code Generation

When generating code, agents MUST:

- Respect the layered deployment model (Global → Geodes → Regional → Stamp → Monitoring)
- Never mix per-CELL resources with global resources in the same module
- Ensure tenant isolation — no cross-tenant data access unless explicitly through the global control plane
- Use `ITenantCacheService` for all tenant routing lookups (never hit Cosmos directly in hot paths)
- Follow the isolated worker model for Azure Functions (no in-process patterns)
- Always use constructor injection for dependencies
- Use `ILogger<T>` for structured logging

### 3. Instruction File Awareness

Agents MUST read and follow the domain-specific instruction files in `.github/instructions/`:

| Instruction File | When to Apply |
|-----------------|---------------|
| `csharp-functions.instructions.md` | Any C# or Azure Functions code |
| `bicep-iac.instructions.md` | Any Bicep templates |
| `testing.instructions.md` | Test files or test generation |
| `docs-style.instructions.md` | Documentation or markdown |
| `deployment-devops.instructions.md` | CI/CD pipelines or scripts |
| `management-portal.instructions.md` | Management portal code |
| `security.instructions.md` | Authentication, authorization, or security |
| `database.instructions.md` | Cosmos DB, Azure SQL, or data access |
| `caching.instructions.md` | Redis or caching patterns |
| `api-patterns.instructions.md` | API design or HTTP endpoints |
| `observability.instructions.md` | Logging, monitoring, or diagnostics |
| `multi-tenant.instructions.md` | Tenant management or isolation |
| `architecture-principles.instructions.md` | Structural or design decisions |
| `blazor.instructions.md` | Blazor Server UI code |
| `graphql.instructions.md` | GraphQL queries or schema |

### 4. Context Gathering Before Action

Before making code changes, agents SHOULD:

1. Read the relevant instruction file(s) for the area being modified
2. Inspect existing patterns in neighboring files for consistency
3. Check `SharedModels.cs` for the current domain model definitions
4. Verify the target .NET version (currently .NET 6) and package versions in `.csproj`
5. Check `CHANGELOG.md` for recent changes if the modification is significant

### 5. Code Generation Guardrails

Agents MUST NOT:

- Generate code targeting .NET 7/8/9 features (project targets .NET 6)
- Use `Newtonsoft.Json` — this solution uses `System.Text.Json` exclusively
- Create functions using the in-process model — use isolated worker model only
- Hard-code connection strings, keys, or secrets — use Key Vault references or environment variables
- Generate Bicep targeting resource-group scope for orchestration — use subscription scope
- Skip null checks on Cosmos DB query results
- Generate code with `Console.WriteLine` — use `ILogger<T>`
- Create public endpoints without authentication/authorization checks
- Assume tenant data is co-located — always route through the CELL assignment logic

### 6. Naming Conventions

Agents MUST follow these naming patterns:

| Element | Pattern | Example |
|---------|---------|---------|
| Azure Functions | `{Verb}{Noun}Function` | `CreateTenantFunction` |
| Services | `{Domain}Service` | `CachingService`, `DiscoveryCacheService` |
| Interfaces | `I{ServiceName}` | `ITenantCacheService` |
| Bicep modules | `{resourceOrLayer}.bicep` | `deploymentStampLayer.bicep` |
| Parameters | `{module}.parameters.json` | `main.parameters.json` |
| Test classes | `{ClassUnderTest}Tests` | `CreateTenantFunctionTests` |
| Test methods | `{Method}_{Scenario}_{ExpectedResult}` | `Run_ValidTenant_ReturnsCreated` |

### 7. Pull Request & Commit Assistance

When helping with PRs or commits:

- Follow Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `infra:`
- Reference issue numbers when applicable: `feat: add tenant migration (#42)`
- PR descriptions should include: what changed, why, testing done, deployment impact
- Suggest `CHANGELOG.md` updates for any user-facing or API changes
- Ensure PR titles are concise but descriptive

### 8. Security-Aware Generation

Agents MUST apply security by default:

- All HTTP-triggered functions require authentication (`AuthorizationLevel.Function` minimum)
- Validate JWT tokens for tenant-facing endpoints using the existing `JwtValidator` pattern
- Never log PII (tenant IDs are OK; email addresses, auth tokens are NOT)
- Use parameterized queries for any SQL access
- Apply `[RequiredScope]` or policy-based authorization for management portal endpoints
- Secrets go in Key Vault, referenced via `@Microsoft.KeyVault(...)` App Settings syntax

### 9. Multi-File Change Coordination

When a change spans multiple files, agents SHOULD:

1. Identify all affected files before starting edits
2. Update interfaces before implementations
3. Update models before consumers
4. Update Bicep parameters when changing Bicep modules
5. Add or update tests for any logic changes
6. Update `CHANGELOG.md` if the change is notable
7. Check for impacts on the management portal if API contracts change

### 10. Error Handling Patterns

When generating error handling code:

```csharp
// ✅ Correct pattern
try
{
    var result = await _cosmosContainer.ReadItemAsync<Tenant>(tenantId, new PartitionKey(tenantId));
    return new OkObjectResult(result.Resource);
}
catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
{
    _logger.LogWarning("Tenant {TenantId} not found", tenantId);
    return new NotFoundResult();
}
catch (Exception ex)
{
    _logger.LogError(ex, "Error retrieving tenant {TenantId}", tenantId);
    return new StatusCodeResult(StatusCodes.Status500InternalServerError);
}
```

## MCP Server Integration

If this repository is configured as an MCP server context:

- Expose tenant management operations as tool definitions
- Ensure all MCP tool responses include structured error information
- Use the existing `SharedModels.cs` types for request/response schemas
- MCP tools should follow the same security patterns as HTTP endpoints
- Log MCP tool invocations through `ILogger<T>` for audit trail

## Agent Testing Guidance

When an agent generates code, it SHOULD also:

1. Generate or update corresponding unit tests
2. Suggest integration test scenarios for cross-service interactions
3. Verify the generated code compiles by referencing existing patterns
4. Flag if the change requires infrastructure updates (Bicep changes)
