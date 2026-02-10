# `.github/instructions/` — Instruction File Index

This folder contains domain-specific instruction files for **GitHub Copilot** and AI coding agents working in the **Azure Stamps Pattern (ASPA)** repository. Each file provides targeted rules, conventions, and patterns for a specific technology area or architectural concern.

## How Instruction Files Work

GitHub Copilot automatically loads these files based on the `applyTo` glob pattern in each file header. When you're editing a file that matches the pattern, Copilot uses the corresponding instructions to generate more accurate, project-aware code.

You can also reference these files manually in Copilot Chat using `#instructions`.

## Instruction File Catalog

### Architecture & Design

| File | Scope | Description |
|------|-------|-------------|
| [architecture-principles.instructions.md](architecture-principles.instructions.md) | Solution-wide | CELL hierarchy, layered deployment, isolation boundaries, CAF/WAF compliance |
| [multi-tenant.instructions.md](multi-tenant.instructions.md) | Tenant management | Tenant lifecycle, CELL assignment, tier model, isolation patterns |
| [multi-environment.instructions.md](multi-environment.instructions.md) | Deployment | Environment promotion (dev → test → staging → prod), parameter patterns |

### Application Code

| File | Scope | Description |
|------|-------|-------------|
| [csharp-functions.instructions.md](csharp-functions.instructions.md) | C# / Azure Functions | .NET 6, isolated worker model, DI patterns, function conventions |
| [blazor.instructions.md](blazor.instructions.md) | Management Portal | Blazor Server components, IDataService, forms, layout conventions |
| [graphql.instructions.md](graphql.instructions.md) | GraphQL API | Hot Chocolate schema, Query/Mutation/Subscription patterns |
| [api-patterns.instructions.md](api-patterns.instructions.md) | HTTP API design | REST conventions, response formats, versioning, APIM integration |

### Infrastructure & Deployment

| File | Scope | Description |
|------|-------|-------------|
| [bicep-iac.instructions.md](bicep-iac.instructions.md) | Bicep templates | Module structure, naming, parameter patterns, subscription-scoped deployment |
| [azure.instructions.md](azure.instructions.md) | Azure services | Service catalog, deployment order, resource management best practices |
| [azd.instructions.md](azd.instructions.md) | Azure Developer CLI | `azd` commands, `azure.yaml` structure, environment management |
| [deployment-devops.instructions.md](deployment-devops.instructions.md) | CI/CD pipelines | GitHub Actions workflows, deployment gates, release process |

### Data & Caching

| File | Scope | Description |
|------|-------|-------------|
| [database.instructions.md](database.instructions.md) | Cosmos DB / Azure SQL | Data modeling, partitioning, consistency, per-CELL SQL patterns |
| [caching.instructions.md](caching.instructions.md) | Redis / IMemoryCache | Cache-aside pattern, TTL policies, ITenantCacheService interface |

### Cross-Cutting Concerns

| File | Scope | Description |
|------|-------|-------------|
| [security.instructions.md](security.instructions.md) | Security | JWT validation, Entra ID, zero-trust networking, Azure Policy |
| [errorhandling.instructions.md](errorhandling.instructions.md) | Error handling | Exception patterns, HTTP status codes, Cosmos error handling |
| [observability.instructions.md](observability.instructions.md) | Monitoring | Structured logging, Application Insights, metric alerts, dashboards |
| [performance.instructions.md](performance.instructions.md) | Performance | Caching strategy, async patterns, Cosmos optimization, benchmarking |

### Process & Quality

| File | Scope | Description |
|------|-------|-------------|
| [testing.instructions.md](testing.instructions.md) | Tests | xUnit + Moq patterns, test categories, naming conventions |
| [docs-style.instructions.md](docs-style.instructions.md) | Documentation | Markdown style, diagram conventions, ADR format |
| [git-workflow.instructions.md](git-workflow.instructions.md) | Git / SCM | Branch strategy, conventional commits, PR workflow |
| [version.instructions.md](version.instructions.md) | Versioning | Semantic Versioning, CHANGELOG format, release management |
| [management-portal.instructions.md](management-portal.instructions.md) | Portal operations | Portal architecture, Dapr integration, Container Apps deployment |

### AI & Agent Guidance

| File | Scope | Description |
|------|-------|-------------|
| [agents.instructions.md](agents.instructions.md) | AI agents / Copilot | Agent behavioral rules, domain awareness, code generation guardrails |

## Adding New Instruction Files

1. Create `{topic}.instructions.md` in this folder
2. Start with an `applyTo:` line specifying the glob pattern for auto-activation
3. Use clear headings, code examples, and tables for scanability
4. Add the file to this README and to `../.github/copilot-instructions.md`
5. Follow the naming convention: `kebab-case.instructions.md`
