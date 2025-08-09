# Data Strategy Plan — CELL Data Plane HA/DR

Last updated: 2025-08-09
Owners: Architecture Guild
Status: Draft (planning document for a future, polished Data Strategy Guide)

## Purpose

Capture decisions, options, and runbooks for the CELL data plane so teams can implement consistent HA/DR, align RPO/RTO targets, and wire this into IaC and operational playbooks. This is a working plan; the formal “Data Strategy Guide” will be derived from here.

## Scope and assumptions

- Applies to CELL-scoped app data stores (per-cell) and any shared/global stores that interact with cells.
- Primary services: Cosmos DB, Azure SQL Database, Azure Storage (Blob); adjust if a workload adds others (e.g., Event Hubs, Redis, MI).
- Compute can be Active/Active, Active/Warm, or Active/Passive; this plan focuses on the persisted data layer to make those modes feasible.

### Layers & scope clarifications

- Global control plane (central):
  - Purpose: Tenant directory, routing, config/state used by the platform itself.
  - Managed centrally; not configurable per team/tenant. Global replication (e.g., additionalLocations) is defined at the global layer.
  - Not covered by per-CELL HA/DR toggles below.
- CELL data plane (regional/zone):
  - Purpose: Application data per CELL; teams can choose HA/DR tier and topology.
  - All parameters and options in this plan (Cosmos multi-region, SQL failover group, Storage ORS/SKU) apply to CELL resources only.

## Technology scope and defaults (persisted app data)

- RDBMS
  - Azure SQL Database (default RDBMS)
  - Azure Database for PostgreSQL – Flexible Server
  - Cosmos DB for PostgreSQL (Citus) — distributed Postgres (advanced/optional)
- Non-SQL
  - Azure Cosmos DB (SQL API default; other APIs case-by-case)
- Storage
  - Azure Blob Storage (default object storage)
  - Azure Files (SMB/NFS; app/shared file semantics)

Defaults
- Prefer Azure SQL Database for relational workloads unless you need Postgres-specific features or horizontal sharding (consider Citus).
- Prefer Cosmos DB (SQL API) for planet-scale, low-latency, multi-region read/write with conflict-tolerance needs.
- Prefer Blob for object data and event sourcing artifacts; use Files only when POSIX/SMB semantics are required.

### Service-specific HA/DR notes (quick reference)

- Azure SQL Database
  - In-region HA: Use zone-redundant tier (e.g., Business Critical; check support in chosen region).
  - Cross-region DR: Auto-failover Group (FOG) with RW/RO listeners; readable secondary for offload.
  - Backup/restore: PITR; Long-term retention (LTR) to meet compliance.
  - Limits: Single-write across regions; Active/Active requires app-level write leadership or sharding.

- Azure Database for PostgreSQL – Flexible Server
  - In-region HA: Zone-redundant HA with automatic failover (primary/standby across zones).
  - Cross-region: Read replicas (including cross-region) for DR and read offload; promotion is manual during DR.
  - Backup/restore: Automated backups with geo-redundant option; PITR supported.
  - Notes: Leader-follower writes (single-write). Consider extension compatibility and maintenance windows.

- Cosmos DB for PostgreSQL (Citus)
  - In-region HA: Built-in high availability within the cluster; shard-based distribution for scale-out.
  - Cross-region: Multi-region strategies may require logical replication or dual clusters; plan for operational complexity and failover runbooks.
  - Use when: You need distributed Postgres with SQL semantics and large scale across nodes; otherwise default to Azure SQL or Flexible Server.

- Azure Cosmos DB (SQL API)
  - In-region HA: Zone redundant where available; session consistency default.
  - Cross-region: Add locations; automatic failover; optionally enable multi-write for Active/Active with conflict resolution (LWW/custom).
  - Backup/restore: Continuous backup (7/30-day tiers) or periodic backup depending on requirements.

- Azure Blob Storage
  - In-region HA: ZRS recommended; enable versioning + soft delete + change feed.
  - Cross-region: GZRS/RA-GZRS for account-level DR; Object Replication (ORS) for container-level async replication with auditability.
  - Restore: Point-in-time restore (PITR) for containers when versioning/restore policy enabled.

- Azure Files
  - In-region HA: Premium FileStorage supports ZRS; Standard supports ZRS.
  - Cross-region: For Standard accounts, GZRS/RA-GZRS is available in many regions (verify); Premium generally ZRS only (no GZRS). DR patterns often use backups or migration tooling (AzCopy/File Sync) to a paired region.
  - Snapshot/backup: Snapshots and Azure Backup for Files for restore scenarios.

## Definitions

- CELL: An independently deployable/regional stamp of app + data.
- Paired CELLs: Two cells in different regions intended to fail over between each other.
- Home Region: The authoritative write region per tenant/workload.
- RPO: Max acceptable data loss (time); RTO: Time to restore service.
- Tiers: Standardized HA/DR capability levels we can choose per dataset.

## Inventory of data stores (fill per workload)

- Cosmos DB: [Yes/No] Account(s): […], Containers: […], Partition key(s): […].
- Azure SQL DB: [Yes/No] Server: […], DBs: […], Tier: […].
- Storage (Blob): [Yes/No] Account: […], Containers: […], SKU: […].
- Other: […].

## HA/DR tiers and targets

Use these tiers as presets when designing per-workload data plans.

- Bronze — In-region HA, no cross-region DR
  - Targets: RPO 0 for zonal failures; RTO < 15 min; no regional DR target
  - Topology: Multi-AZ only (ZRS/Zone redundant)
  - Services: Storage ZRS, Cosmos zone redundant, SQL zone redundant tier

- Silver — Geo-read + manual/auto failover
  - Targets: RPO ≤ 15 min; RTO 30–60 min
  - Topology: Primary + secondary region, single-write
  - Services: Cosmos additionalLocations + auto-failover, SQL Auto-failover Group (FOG), Storage RA-GZRS or Object Replication (one-way)

- Gold — Active primary + warm standby
  - Targets: RPO ≤ 5 min; RTO ≤ 15–30 min
  - Topology: Paired CELLs, writes to leader, reads anywhere
  - Services: Cosmos single-write multi-region, SQL FOG, Storage Object Replication per container; standby compute sized low

- Platinum — Active/Active
  - Targets: RPO ~0 (conflict-tolerant), RTO ≤ 5–15 min
  - Topology: Paired (or multi) CELLs, multi-write where supported, read/write in both regions
  - Services: Cosmos multi-write with conflict policy; SQL remains single-write (use per-tenant leader or sharding); Storage bi-directional Object Replication with scoped prefixes

## Topology options (how to implement)

- Multi-AZ only (baseline)
  - Use zone-redundant SKUs and features (SQL zone redundant tier, Storage ZRS, Cosmos isZoneRedundant).

- Paired CELLs (single-write)
  - Cosmos: Add secondary locations; enableAutomaticFailover; enableMultipleWriteLocations=false.
  - SQL DB: Use Auto-failover Group; app uses RW/RO listeners; writes go to primary.
  - Blob: RA-GZRS or Object Replication from primary to secondary account.

- Paired CELLs (multi-write where possible)
  - Cosmos: enableMultipleWriteLocations=true with LWW or custom conflict resolution.
  - SQL DB: No native multi-write; designate tenant home region for writes.
  - Blob: Consider bi-directional Object Replication by container/prefix; avoid loops.

## Tenant routing and write leadership

- Store per-tenant metadata: homeRegion, partnerRegion, writeLeader (service-level).
- Reads can be local; writes must follow the leader for SQL and any non-conflict-tolerant store.
- For Cosmos A/A: choose conflict policy (prefer LWW on updatedAt) and ensure idempotent upserts.

## IaC toggles and parameters (proposed)

Thread these parameters from main into the stamp/regional layers and default them conservatively.

- Cosmos DB
  - cosmosAdditionalLocations: array
  - cosmosMultiWrite: bool
  - enableAutomaticFailover: inferred from additional locations

- Azure SQL DB
  - enableSqlFailoverGroup: bool
  - sqlSecondaryServerId: string (resourceId of partner)

- Storage (Blob)
  - storageSkuName: Premium_ZRS | Standard_GZRS | Standard_RAGZRS
  - enableStorageObjectReplication: bool
  - storageReplicationDestinationId: string

Document the exact resource names in Bicep once wired (see code comments in stamp layer).

## Example parameterization (Bicep parameters)

Two quick examples to make the knobs concrete. Aligns with `AzureArchitecture/main.bicep` and `deploymentStampLayer.bicep`.

Example A — conservative defaults (Silver-ish) with per-cell overrides:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "cosmosAdditionalLocations": { "value": ["westus2"] },
    "cosmosMultiWrite": { "value": false },
    "storageSkuName": { "value": "Premium_ZRS" },
    "enableStorageObjectReplication": { "value": false },
    "enableSqlFailoverGroup": { "value": false },
    "cells": {
      "value": [
        {
          "geoName": "northamerica",
          "regionName": "eastus",
          "cellName": "cell1",
          "cellType": "Shared",
          "availabilityZones": ["1","2"],
          "maxTenantCount": 100,
          "baseDomain": "eastus.stamps.contoso.com",
          "keyVaultName": "kv-stamps-na-eus",
          "logAnalyticsWorkspaceName": "law-stamps-na-eus",
          "enableStorageObjectReplication": true,
          "storageReplicationDestinationId": "/subscriptions/<SUBID>/resourceGroups/<RG>/providers/Microsoft.Storage/storageAccounts/stnorthamericawestus2cell1"
        },
        {
          "geoName": "northamerica",
          "regionName": "eastus",
          "cellName": "cell2",
          "cellType": "Dedicated",
          "availabilityZones": ["1","2","3"],
          "maxTenantCount": 1,
          "baseDomain": "eastus.stamps.contoso.com",
          "keyVaultName": "kv-stamps-na-eus",
          "logAnalyticsWorkspaceName": "law-stamps-na-eus",
          "enableSqlFailoverGroup": true,
          "sqlSecondaryServerId": "/subscriptions/<SUBID>/resourceGroups/<RG>/providers/Microsoft.Sql/servers/<PARTNER_SQL_SERVER_NAME>"
        }
      ]
    }
  }
}
```

Example B — Platinum for one CELL (Cosmos multi-write):

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "cosmosAdditionalLocations": { "value": ["westus2"] },
    "cosmosMultiWrite": { "value": false },
    "cells": {
      "value": [
        {
          "geoName": "northamerica",
          "regionName": "eastus",
          "cellName": "cell1",
          "cellType": "Shared",
          "availabilityZones": ["1","2"],
          "maxTenantCount": 100,
          "baseDomain": "eastus.stamps.contoso.com",
          "keyVaultName": "kv-stamps-na-eus",
          "logAnalyticsWorkspaceName": "law-stamps-na-eus",
          "cosmosMultiWrite": true
        }
      ]
    }
  }
}
```

Notes
- Per-cell overrides use the same property names as the top-level knobs (e.g., `cosmosMultiWrite`, `enableSqlFailoverGroup`).
- SQL FOG requires `sqlSecondaryServerId` to be a full resource ID of the partner SQL Server.
- Blob ORS requires `storageReplicationDestinationId` pointing to the destination Storage Account.
 - See concrete, runnable samples in `AzureArchitecture/examples/`.

## Operational runbooks (first draft)

- Planned regional failover (single-write)
  1) Drain or briefly quiesce writes
  2) Promote secondaries (Cosmos re-prioritize; SQL FOG automatic/manual)
  3) Flip tenant homeRegion and app config; restart apps; reheat caches
  4) Validate health and data parity; resume traffic

- Unplanned failover
  - Trigger health-based promotion; accept LWW conflict risk on Cosmos
  - SQL via FOG automatic failover; ensure app uses RW listener

- Failback
  - Rehydrate original primary; catch up replication; swap roles during low-traffic window

- Blob account failover vs ORS
  - Prefer ORS (object replication) for targeted, auditable copies; use account failover for last-resort disaster

## Testing and drills

- Quarterly DR game day per tier; measure actual RPO/RTO
- Data integrity checks: row counts/hashes per tenant across regions
- PITR tests: SQL and Blob restore to sandbox regularly

## Observability and KPIs

- Cosmos: Replication lag, RU/s consumption, conflicts count
- SQL: FOG role, failover events, AG health, latency
- Storage: ORS policy status, replication backlog, versioning metrics

## Security and data governance

- Private Endpoints on all data services; no public access
- CMK/Double encryption per policy
- Data residency and paired-region policy compliance

## Cost considerations

- RU duplication for Cosmos in multi-region; standby compute for warm cells
- Egress and storage for ORS; premium vs standard SKUs
- Use tagging and cost exports per cell/tenant

## Decision records (template)

- Context:
- Decision:
- Tier/targets:
- Topology:
- Services + toggles:
- Runbooks impacted:
- Review date:

## Per-workload matrix (fill out)

| Workload | Data store | Tier | Home region | Partner region | Write leader | Cosmos multi-write | SQL FOG | Blob ORS | RPO target | RTO target |
|---|---|---|---|---|---|---|---|---|---|---|
| ExampleApp | Cosmos/Orders | Gold | eastus | westus | eastus | false | n/a | appdata->appdata | ≤5m | ≤30m |

## Open questions

- Which workloads require Platinum vs Gold?
- Per-tenant home region assignment rules?
- Regulatory data residency constraints per dataset?

## Next steps

- Choose paired region map for each CELL
- Wire IaC toggles into Bicep and surface in parameters
- Add tenant metadata (homeRegion/writeLeader) to control plane
- Schedule first DR drill and define SLOs

## Data sharding and shaping (planning)

Why: Sharding and data shape choices determine how well HA/DR modes work, cost, and operational complexity. Use this section to record per-workload decisions.

### When to shard vs. partition vs. isolate

- Shard (many DBs/containers): High tenant count, uneven hotspots, per-tenant RPO/RTO, or data residency differences.
- Partition inside one store: Moderate scale with consistent access patterns; fewer objects to operate.
- Isolate per-tenant database/account: Strong isolation, custom SLOs/compliance, simpler lifecycle at the cost of object sprawl.

Decision drivers
- HA/DR mode: A/A favors conflict-tolerant stores or strict write leadership; A/W and A/P can use single-writer + replicas.
- Tenant isolation: Dedicated vs shared; noisy neighbors; per-tenant cost tracking.
- Query patterns: Cross-tenant analytics vs per-tenant OLTP; need for co-located joins.
- Residency/compliance: Keep shards in specific regions/geos.

### Patterns by HA/DR mode

- Active/Active
  - Prefer conflict-tolerant/CRDT-like behavior (Cosmos multi-write) or strict per-tenant write leadership (SQL/Postgres).
  - Route writes to tenant home region; reads local where safe; avoid multi-region 2PC.
  - Keep shard boundaries aligned to tenantId to minimize cross-shard writes.

- Active/Warm Standby
  - Single-writer with async replicas/secondaries; keep compute low in standby.
  - Validate replica catch-up (lag) before promoting during failover.

- Active/Passive
  - Backups + restore and/or account-level failover; IaC and secrets ready for cold start.

### Technology notes and configurations

- Azure SQL Database
  - Sharding options: per-tenant database (recommended for many tenants), schema-per-tenant, or table partitioning for few tenants.
  - Failover: Use Auto-failover Groups; include all tenant DBs; app uses RW/RO listeners.
  - A/A: Not multi-write; enforce write leadership by tenant; reads can use RO secondary.
  - Cross-tenant analytics: Use dedicated analytics path (ETL/ELT) or Elastic Query; avoid heavy cross-DB joins on OLTP.
  - Ops: Align DB naming to tenantId; tag by tenant; automate shard map/lookup in control plane.

- Azure Database for PostgreSQL – Flexible Server
  - Patterns: schema-per-tenant or table partitioning by tenant_id; create cross-region read replicas; promote on failover.
  - A/A: Avoid multi-primary; keep a single write leader; use logical replication for selective flows if needed (advanced).
  - Ops: Tune autovacuum; manage extension needs; plan maintenance windows.

- Cosmos DB for PostgreSQL (Citus)
  - Distribute by tenant_id; co-locate related tables; use reference tables for small shared dims.
  - Rebalance shards as tenants grow; monitor placement.
  - Cross-region: Typically leader-follower (async) clusters; plan DR runbooks; multi-write across regions is non-trivial.

- Azure Cosmos DB (SQL API)
  - Partition key: Prefer /tenantId (or composite synthetic key) to keep tenant data co-located.
  - Multi-write A/A: enableMultipleWriteLocations=true; choose conflict policy (LWW on updatedAt or custom sproc).
  - Throughput: Prefer per-container autoscale; budget extra RU for multi-region replication.
  - Data shape: Denormalize for aggregate reads; avoid cross-partition fan-out in hot paths.

- Azure Blob Storage
  - Namespace: Container-per-tenant or shared container with tenantId/hashed prefixes to avoid hotspots.
  - Replication: ORS rules per container; RA-GZRS for account-level DR; enable versioning + soft delete + change feed + PITR.
  - Concurrency: Use ETags + conditional writes; avoid cross-region multi-writer patterns unless object keys are unique and immutable.

- Azure Files
  - Layout: Directory-per-tenant; snapshots + Azure Backup for restore.
  - DR: ZRS for in-region; Standard may support GZRS/RA-GZRS (verify region); Premium is typically ZRS-only—pair with backups or sync tooling for cross-region.

### Guardrails and checks

- Pick the shard key first (usually tenantId); confirm it appears in 95%+ of access paths.
- For A/A, document conflict policy per container/table; simulate conflicts in tests.
- Keep read paths cross-shard tolerant (fallback to fan-out reads only off the hot path).
- Maintain a control-plane directory: tenant → homeRegion/partnerRegion → shard/db/container → writeLeader.
- Add synthetic IDs and timestamps to support LWW and idempotency.
