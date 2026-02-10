# Copilot Instructions — Azure Stamps Pattern (ASPA)

## Project Overview

This is the **Azure Stamps Pattern (ASPA)** — an enterprise-grade, CAF/WAF-compliant (94/100) reference architecture for building secure, multi-tenant SaaS platforms on Azure. It implements a **GEO → Region → Availability Zone → CELL** hierarchy supporting both shared and dedicated tenancy models.

## Repository Structure

| Path | Purpose |
|------|---------|
| `AzureArchitecture/` | .NET 6 Azure Functions (isolated worker), Bicep IaC modules, and tests |
| `management-portal/` | Blazor Server management portal with Hot Chocolate GraphQL backend |
| `docs/` | Architecture guides, deployment guides, compliance analyses, operations runbooks |
| `scripts/` | PowerShell deployment, validation, and operational scripts |
| `infra/` | ALZ starter Bicep templates |
| `config/` | Region mapping and configuration data |
| `samples/` | Sample applications (TaskTracker) |
| `.github/workflows/` | CI/CD pipelines (Bicep validation, .NET build/test, deployment) |

## Key Domain Language

- **CELL** = a deployment stamp (shared or dedicated). Shared CELLs host 10–100 tenants; dedicated CELLs host 1 enterprise tenant.
- **TenantTier** enum: `Startup`, `SMB`, `Shared`, `Enterprise`, `Dedicated`
- **CellType** enum: `Shared`, `Dedicated`
- **TenantStatus** lifecycle: `Active` → `Inactive` → `Suspended` → `Migrating` → `Provisioning` → `Deprovisioning`
- Cosmos DB is the global control plane data store (database: `globaldb`, containers: `tenants`, `cells`)
- Partition key for tenants = `tenantId`

## Technology Stack

- **.NET 6** / Azure Functions v4 / isolated worker model (`dotnet-isolated`)
- **Bicep** for all infrastructure as code (subscription-scoped orchestration)
- **Blazor Server** management portal with **Hot Chocolate** GraphQL backend
- **Azure Cosmos DB**, **Azure SQL**, **Azure Redis Cache**, **Azure Front Door**, **APIM**, **Key Vault**
- **Azure Developer CLI** (`azd`) for management portal deployment
- **xUnit + Moq** for testing

## Quick References

See `.github/instructions/` for detailed area-specific instructions ([full index](instructions/README.md)):

### Architecture & Design
- `architecture-principles.instructions.md` — CELL hierarchy, layered deployment, CAF/WAF compliance
- `multi-tenant.instructions.md` — Tenant lifecycle, CELL assignment, tier model, isolation
- `multi-environment.instructions.md` — Environment promotion (dev → test → staging → prod)

### Application Code
- `csharp-functions.instructions.md` — C# and Azure Functions conventions
- `blazor.instructions.md` — Blazor Server components, IDataService, forms, layout
- `graphql.instructions.md` — Hot Chocolate GraphQL schema and query patterns
- `api-patterns.instructions.md` — REST API design, response formats, APIM integration

### Infrastructure & Deployment
- `bicep-iac.instructions.md` — Bicep / Infrastructure as Code standards
- `azure.instructions.md` — Azure service catalog, deployment order, resource management
- `azd.instructions.md` — Azure Developer CLI commands and environment management
- `deployment-devops.instructions.md` — CI/CD pipelines and release process

### Data & Caching
- `database.instructions.md` — Cosmos DB and Azure SQL data patterns
- `caching.instructions.md` — Redis / IMemoryCache, cache-aside, ITenantCacheService

### Cross-Cutting Concerns
- `security.instructions.md` — JWT validation, Entra ID, zero-trust, Azure Policy
- `errorhandling.instructions.md` — Exception patterns, HTTP status codes, retry logic
- `observability.instructions.md` — Structured logging, App Insights, metric alerts
- `performance.instructions.md` — Caching strategy, async patterns, Cosmos optimization

### Process & Quality
- `testing.instructions.md` — xUnit + Moq patterns and test conventions
- `docs-style.instructions.md` — Documentation style guide
- `git-workflow.instructions.md` — Branch strategy, conventional commits, PR workflow
- `version.instructions.md` — Semantic Versioning, CHANGELOG format, release management
- `management-portal.instructions.md` — Portal architecture, Dapr, Container Apps

### AI & Agent Guidance
- `agents.instructions.md` — Agent behavioral rules, domain awareness, code generation guardrails

@azure Rule - Use Azure Best Practices: When generating code for Azure, running terminal commands for Azure, or performing operations related to Azure, invoke your `azure_development-get_best_practices` tool if available.
