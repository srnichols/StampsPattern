# 🧭 Azure Stamps Pattern - Data Strategy Guide

---

Practical blueprint for designing the CELL data plane, HA/DR tiers, replication topologies, tenancy-aware routing, and operational runbooks, so teams can deliver reliable, compliant, and cost-effective data services.

- What’s inside: Tiers and targets, topology patterns, service recipes (Cosmos/SQL/Postgres/Storage), routing, sharding, IaC knobs, runbooks, testing, observability, compliance, cost
- Best for: Data/solution architects, platform engineers, SRE/operations, and compliance teams
- Outcomes: Clear choices per workload, repeatable IaC, predictable RPO/RTO, and operator-ready runbooks

---

## 👤 Who Should Read This Guide?

- Data & Solution Architects: Choose per-workload tiers and topologies
- Platform Engineers: Implement IaC toggles and environment wiring
- SRE/Operations: Runbooks, drills, and observability checklists
- Compliance & Security: Validate residency, encryption, and access controls

---

> Scope note
>
> - Global control plane data (tenant directory/routing) is centrally managed and not configurable per team; it follows platform defaults and global replication strategy.
> - This guide focuses on the CELL data plane (regional/zone resources owned by app teams). All HA/DR knobs and recipes apply to CELL resources unless explicitly stated.

## 🧭 Quick Navigation

| Section | Focus Area | Time to Read | Best for |
|---------|------------|--------------|----------|
| [🎯 Data Strategy Overview](#-data-strategy-overview) | What we solve and key decisions | 5 min | All readers |
| [🧪 Technology Scope & Defaults](#-technology-scope--defaults) | Supported data services and defaults | 6 min | Architects |
| [🏷️ Tiers & SLO Targets](#️-tiers--slo-targets) | Bronze/Silver/Gold/Platinum | 10 min | Architects |
| [🏛 Topology Patterns](#-topology-patterns) | Zones, paired cells, A/A vs A/W | 10 min | Architects, DevOps |
| [🧩 Service Recipes](#-service-recipes) | Cosmos, SQL, Postgres, Storage | 15 min | Engineers |
| [🧭 Tenant Routing](#-tenant-routing) | Home region and write leadership | 10 min | Architects |
| [🧱 Data Sharding & Shaping](#-data-sharding--shaping) | Shard keys, partitioning, isolation | 10 min | Architects |
| [🧱 IaC Toggles](#-iac-toggles) | Bicep parameters and wiring | 10 min | Engineers |
| [🛠️ Runbooks](#️-runbooks) | Planned/unplanned failover/failback | 10 min | Operations |
| [🧪 Testing & Drills](#-testing--drills) | RPO/RTO validation and PITR | 10 min | SRE |
| [📈 Observability](#-observability) | Metrics, logs, and alerts | 10 min | SRE |
| [🛡️ Compliance & Governance](#️-compliance--governance) | Residency, encryption, access | 10 min | Compliance |
| [💰 Cost Considerations](#-cost-considerations) | Cost drivers and trade-offs | 5 min | IT Leaders |

---

## 🎯 Data Strategy Overview

Design a consistent, repeatable approach to CELL data HA/DR that aligns with tenant needs and budget. Choose a tier per dataset, apply the matching topology, and enable it via IaC.

Key decisions:

- Which tier (Bronze/Silver/Gold/Platinum) per dataset?
- Paired region for each CELL? Single-write vs multi-write?
- Tenant home region and write leader assignment model?

---

## 🧪 Technology Scope & Defaults

Supported services (persisted app data):

- RDBMS
  - Azure SQL Database (default relational choice)
  - Azure Database for PostgreSQL – Flexible Server
  - Cosmos DB for PostgreSQL (Citus) for distributed Postgres (advanced)
- Non‑SQL
  - Azure Cosmos DB (SQL API default)
- Storage
  - Azure Blob Storage (default object storage)
  - Azure Files (SMB/NFS semantics)

Defaults

- Prefer Azure SQL for most OLTP relational workloads; choose Postgres where feature parity or ecosystem matters.
- Prefer Cosmos DB (SQL API) for planet-scale, multi-region, low-latency with conflict tolerance.
- Prefer Blob for object data; Files only when file semantics are required.

---

## 🏷️ Tiers & SLO Targets

- Bronze (In-region HA)
  - Zonal resilience only. No cross-region DR.
  - Target: RPO 0 for zonal events; RTO < 15 min.
- Silver (Geo-read + failover)
  - Primary + secondary region; single-write.
  - Target: RPO ≤ 15 min; RTO 30–60 min.
- Gold (Active primary + warm standby)
  - Paired cells; reads regional; writes to leader.
  - Target: RPO ≤ 5 min; RTO ≤ 15–30 min.
- Platinum (Active/Active)
  - Multi-write where supported; conflict-tolerant.
  - Target: RPO ≈ 0; RTO ≤ 5–15 min.

---

## 🏛 Topology Patterns

- Multi-AZ (baseline): Zone-redundant tiers and features.
- Paired Cells (single-write): Auto-failover, read replicas.
- Paired Cells (multi-write): Cosmos multi-write + conflict policy; SQL/Postgres stay single-write with strict leader.

When to choose which:

- Low complexity, low cost → Bronze/Silver
- Mission-critical, tight SLOs → Gold/Platinum

---

## 🧩 Service Recipes

- Azure SQL Database
  - In‑region HA: Use zone‑redundant database option (e.g., Business Critical where available).
  - Cross‑region: Auto‑failover Groups (FOG) with RW/RO listeners; readable secondary for offload.
  - Backups: PITR + optional Long‑Term Retention.
  - Notes: Single‑writer across regions; use per‑tenant write leadership or sharding.

- Azure Database for PostgreSQL – Flexible Server
  - In‑region HA: Zone‑redundant HA with automatic failover.
  - Cross‑region: Read replicas with manual promotion during DR.
  - Backups: Automated backups with PITR; consider geo‑redundant backup option.
  - Notes: Single‑writer; mind extension compatibility and maintenance windows.

- Cosmos DB for PostgreSQL (Citus)
  - HA/Scale: Distributed shards; built‑in HA within cluster.
  - Cross‑region: Dual clusters/replication patterns are possible but operationally advanced.
  - Notes: Choose when you need distributed Postgres + SQL semantics at scale.

- Azure Cosmos DB (SQL API)
  - In‑region HA: Zone‑redundant where supported; session consistency default.
  - Cross‑region: Additional locations + automatic failover; optional multi‑write (A/A) with conflict policy (LWW/custom).
  - Backups: Continuous backup (7/30‑day tiers) or periodic.

- Azure Storage (Blob)
  - In‑region HA: ZRS + versioning + soft delete + change feed + optional PITR.
  - Cross‑region: GZRS/RA‑GZRS for account‑level DR; Object Replication (ORS) for container‑level async replication.

- Azure Files
  - In‑region HA: ZRS (Standard/Premium options vary by region).
  - Cross‑region: Standard often supports GZRS/RA‑GZRS (verify); Premium typically ZRS only, pair with backups or sync tooling.

---

## 🧭 Tenant Routing

- Record per‑tenant: homeRegion, partnerRegion, and writeLeader per datastore.
- Reads can be local; writes must follow the leader for SQL/Postgres/Files and any non‑conflict‑tolerant store.
- Cosmos A/A: prefer LWW on updatedAt and idempotent upserts.

---

## 🧱 Data Sharding & Shaping

- When to shard vs partition vs isolate
  - Shard (many DBs/containers): high tenant count, hotspots, per‑tenant SLOs, or data residency differences.
  - Partition within one store: moderate scale and simpler operations.
  - Isolate per‑tenant database/account: strong isolation, simpler lifecycle; more objects.
- HA/DR interactions
  - A/A: conflict‑tolerant store (Cosmos multi‑write) or strict write leadership per tenant.
  - A/W: single‑writer + async replicas; validate lag before promotion.
  - A/P: backups + restore, account failover as last resort.
- Tech tips
  - SQL/Postgres: per‑tenant DB/schema or partition by tenant_id; use FOG/replicas.
  - Cosmos: partition by /tenantId; avoid cross‑partition hot paths; choose conflict policy.
  - Blob/Files: container/dir per tenant; use ORS (Blob) and snapshots/backups (Files).

---

## 🧱 IaC Toggles

Expose and thread these parameters through main → regional/stamp layers:

- Cosmos: cosmosAdditionalLocations (array), cosmosMultiWrite (bool)
- SQL: enableSqlFailoverGroup (bool), sqlSecondaryServerId (string)
- Storage: storageSkuName (Premium_ZRS | Standard_GZRS | Standard_RAGZRS), enableStorageObjectReplication (bool), storageReplicationDestinationId (string)

---

## 🛠️ Runbooks

- Planned failover: drain writes → promote data → flip routing → reheat caches → validate
- Unplanned failover: health‑triggered promotion (Cosmos conflicts possible); SQL/Postgres automatic/manual depending on config
- Failback: resync and swap roles during low‑traffic windows

---

## 🧪 Testing & Drills

- Quarterly DR exercises per tier; capture actual RPO/RTO
- Data integrity checks across regions (counts/hashes)
- Regular PITR tests for SQL/Postgres and Blob; restore to sandbox

---

## 📈 Observability

- Cosmos: replication lag, RU/s, conflict count
- SQL/Postgres: FOG/replica state, failover events, latency
- Storage: ORS status, backlog, versioning/snapshot metrics

---

## 🛡️ Compliance & Governance

- Private endpoints only; disable public network access
- CMK/double encryption where required; data residency adherence
- Policy‑as‑code to enforce redundancy/security baselines

---

## 💰 Cost Considerations

- Multi‑region costs: RU duplication (Cosmos), replicas (SQL/Postgres), storage + egress (ORS)
- Warm standby compute: keep minimal and scale on failover
- Use tags and exports to allocate per cell/tenant

---

## 📚 Related Guides

- [Architecture Guide](./ARCHITECTURE_GUIDE.md)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)
- [Operations Guide](./OPERATIONS_GUIDE.md)
- [Security Guide](./SECURITY_GUIDE.md)
- [Parameterization Guide](./PARAMETERIZATION_GUIDE.md)
- [Cost Optimization Guide](./COST_OPTIMIZATION_GUIDE.md)

---

*Last updated: August 2025*
