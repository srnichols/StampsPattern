# Architecture Principles — Instructions

applyTo: "**/*.bicep,**/*.cs,docs/ARCHITECTURE_GUIDE.md"

## Core Pattern

This solution implements the **Azure Stamps Pattern** — a zone-aware deployment model organized as:

```
GEO → Region → Availability Zone → CELL
```

Each CELL is a fully self-contained deployment stamp with its own compute, data, networking, and security resources.

## Key Architectural Principles

### 1. CELL-Based Isolation

- A **CELL** is the atomic deployment unit (stamp)
- **Shared CELLs**: Host 10–100 tenants with application-level isolation (cost-optimized)
- **Dedicated CELLs**: Host exactly 1 enterprise tenant with full infrastructure isolation (compliance-ready)
- CELLs are independently deployable, scalable, and recoverable
- Each CELL has its own SQL database, storage, Key Vault, and Container Apps

### 2. Layered Module Architecture

Infrastructure is organized into composable layers:

| Layer | Scope | Key Resources |
|-------|-------|---------------|
| `globalLayer` | Worldwide | Front Door, Traffic Manager, DNS, global Function Apps, global Cosmos DB |
| `geodesLayer` | Per-GEO | APIM Premium, global control plane Cosmos DB replication |
| `regionalLayer` | Per-Region | Regional networking, VNets, subnets |
| `deploymentStampLayer` | Per-CELL | SQL Server, Storage, Key Vault, Container Apps, App Gateway |
| `monitoringLayer` | Per-Region | Log Analytics, Application Insights, dashboards |

### 3. Global Control Plane

- **Cosmos DB** (`globaldb`) acts as the single source of truth for tenant routing and CELL metadata
- Containers: `tenants` (partition key: `tenantId`), `cells` (partition key: `cellId`)
- Global Function Apps handle tenant onboarding, migration, and routing decisions
- Read replicas distributed across regions for low-latency lookups

### 4. Zero-Trust Security

- Default deny-all network rules with explicit allow-listed paths
- Every request validated: Application Gateway WAF → APIM JWT validation → Function auth
- Private endpoints for data services (Cosmos DB, SQL, Storage)
- Managed Identity everywhere — no stored credentials
- Security headers enforced at APIM level (HSTS, X-Frame-Options, X-Content-Type-Options)

### 5. Environment Parity

- All four environments (`dev`, `test`, `staging`, `prod`) deploy from the same Bicep templates
- Environment differences controlled via parameters, not separate templates
- Cost optimization: non-prod uses Developer SKU APIM, Free-tier Defender, smaller SQL SKUs
- Production: Premium APIM, zone-redundant Cosmos, paid Defender plans

### 6. Flexible Tenancy Economics

| Tier | CELL Type | Monthly Cost | Max Tenants/CELL |
|------|-----------|--------------|------------------|
| Startup | Shared | ~$8/tenant | 100 |
| SMB | Shared | ~$16/tenant | 100 |
| Shared | Shared | ~$16/tenant | 100 |
| Enterprise | Dedicated | ~$3,200/tenant | 1 |
| Dedicated | Dedicated | ~$3,200/tenant | 1 |

Compliance add-ons: HIPAA (+$50), SOX (+$100), PCI-DSS (+$75), FedRAMP (+$200)

### 7. Compliance by Design

Supported standards: HIPAA, SOX, PCI-DSS, GDPR, ISO 27001, SOC 2 Type II, FedRAMP, CCPA

- Compliance requirements stored per-tenant and matched during CELL assignment
- Policy-as-code enforcement via Azure Policy (management group scope)
- Automated audit trails and governance at scale

### 8. Resilience & Availability

- Multi-region, multi-zone deployment topology
- Front Door for global load balancing and failover
- Traffic Manager as secondary DNS-based routing
- Target SLAs: Basic (99.5%), Standard (99.9%), Premium (99.95%), Enterprise (99.99%)
- Automated CELL capacity monitoring and provisioning

## Design Decision Protocol

When making architectural decisions:

1. Preserve CELL isolation — never share data stores across CELLs
2. Keep the global control plane stateless where possible
3. Prefer managed services over self-hosted
4. Make everything environment-parameterized
5. Default to the most secure option; allow opt-out for dev/test
6. Document the "why" in code comments, not just the "what"
