# Multi-Tenant — Instructions

applyTo: "AzureArchitecture/**/*.cs,AzureArchitecture/**/*.bicep"

## Tenancy Model

This solution implements a **flexible tenancy** model where tenants are assigned to CELLs based on their tier, compliance needs, and capacity.

### Tenant Tiers

| Tier | CELL Type | Isolation | Cost |
|------|-----------|-----------|------|
| `Startup` | Shared | Application-level | ~$8/mo |
| `SMB` | Shared | Application-level | ~$16/mo |
| `Shared` | Shared (default) | Application-level | ~$16/mo |
| `Enterprise` | Dedicated | Full infrastructure | ~$3,200/mo |
| `Dedicated` | Dedicated | Full infrastructure | ~$3,200/mo |

### CELL Assignment Logic

When creating a tenant (`CreateTenantFunction`):

1. **Enterprise/Dedicated tiers** → Find an empty dedicated CELL matching compliance requirements
   - Prefer CELLs with exact compliance feature match
   - If none available, auto-provision a new dedicated CELL (if under region limit)
2. **Startup/SMB/Shared tiers** → Find a shared CELL with available capacity
   - Select the CELL with the **lowest tenant count** (load balancing)
   - Ensure compliance requirements are met
   - If all shared CELLs are at capacity, auto-provision a new shared CELL

### Tenant Lifecycle

```
Provisioning → Active → (Migrating) → Active
                ↓                        ↓
            Inactive → Suspended → Deprovisioning
```

- `Active` — fully operational
- `Inactive` — paused but resources preserved
- `Suspended` — billing or compliance hold
- `Migrating` — transitioning between CELLs (Shared → Dedicated upgrade path)
- `Provisioning` — initial onboarding
- `Deprovisioning` — scheduled for teardown

### Tenant Data Model

Key fields on `TenantInfo`:

- `tenantId` (partition key), `subdomain` — identity
- `cellBackendPool`, `cellName` — routing
- `tenantTier`, `region` — placement
- `complianceRequirements` — list of standards (HIPAA, SOX, etc.)
- `businessSegment` — Startup, SMB, Enterprise, Government, Healthcare, Financial
- `slaLevel` — Basic, Standard, Premium, Enterprise
- `estimatedMonthlyApiCalls` — capacity planning

### Tenant Routing

- `CachedTenantRouting` is stored in Redis/memory cache (1-hour TTL)
- Lookup path: Cache → Cosmos DB query by `subdomain`
- Cache invalidation required on migration or CELL reassignment
- Route returns: `cellBackendPool`, `cellName`, `region`, `tenantTier`

### CELL Capacity Management

- `CellManagementFunction` monitors capacity on a 15-minute schedule
- Auto-provisions new CELLs when shared CELLs exceed capacity threshold
- `MaxCellsPerRegion` (default 20) and `MaxTenantsPerSharedCell` (default 100) are configurable
- CELL analytics available via `GET /api/cells/analytics`

### Migration (Shared → Dedicated)

- `TenantMigrationFunction` handles tier upgrades
- Validates migration eligibility before proceeding
- Updates tenant status to `Migrating` during transition
- Reassigns to new dedicated CELL, updates cache
- Rollback on failure

### Multi-Tenancy Code Conventions

- Always pass `tenantId` as Cosmos DB partition key for reads/writes
- Never mix tenant data across partition boundaries
- Validate tenant ownership in JWT claims before returning data
- Log tenant context with structured logging: `_logger.LogInformation("... tenant {TenantId}", tenant.tenantId)`
- Cache keys must be tenant-scoped: `tenant:routing:{tenantId}`
