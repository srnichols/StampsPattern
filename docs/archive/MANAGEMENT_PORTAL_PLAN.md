# Management Portal (Control Plane UI) - Implementation Plan

Status: Draft
Owner: Platform Team
Scope: Tenant metadata, routing, lifecycle operations
Hosting: Azure Container Apps (ACA)
UI: .NET 9 Blazor Web App (Server/interactive) + Bootstrap 5
Data: Azure Cosmos DB (NoSQL, SQL API)
Data Access: Data API Builder (GraphQL) + Azure Functions (commands)
Observability: Azure Application Insights

---

## Goals & Non-Goals

- Goals
  - Provide a control plane UI to manage tenant metadata, placement, routing rules, and lifecycle operations.
  - Enable safe migrations (shared → dedicated, cell-to-cell) with auditable workflows.
  - Expose a GraphQL API for CRUD and a command surface for complex operations.
  - Integrate with existing Stamps Global layer (routing/cosmos/apim).
- Non-Goals
  - Direct infra provisioning in UI (handled via Functions/automation behind commands).
  - Replacing existing operational dashboards (complement, not replace).

---

## High-Level Architecture

- Blazor Web App (Server/interactive) hosted on ACA
  - Bootstrap 5 for styling, responsive layout
  - Auth via Entra ID (App roles: Platform.Admin, Operator, Reader)
- GraphQL via Data API Builder (DAB) fronting Cosmos DB containers
  - CRUD for tenants, cells, operations, catalogs
  - Role-based permissions & projections
- Command Handlers via Azure Functions (HTTP-trigger)
  - Complex ops: tenant migration, rebalance, suspend/resume, decommission
  - Emits Event Grid events for downstream automation
- Cosmos DB (NoSQL) – Global account
  - Database: `stamps-control-plane`
  - Containers: `tenants` (pk: /tenantId), `cells` (pk: /cellId), `operations` (pk: /tenantId), `catalogs` (pk: /type)
- App Insights + Dashboards/Workbooks

---

## Data Model (Initial)

- tenants
  - id, tenantId (pk), displayName, orgDomain, tier, complianceFlags[], status
  - placement { cellId, geo, region, availabilityZones }
  - routing { strategy, baseDomain, apimProductId, trafficWeights? }
  - slaTarget, backupPolicyRef, tags, createdAt, updatedAt
- cells
  - id, cellId (pk), geo, region, azConfig, capacity, status, utilizationSnapshot
- operations
  - id, tenantId (pk), type (migration|suspend|rebalance|decommission), status
  - payload { fromCellId, toCellId, steps[], notes }, createdAt, completedAt
- catalogs
  - id, type (regions|geos|skuProfiles|policies), value

Partitioning & Transactions
- Tenant-scoped writes live under `/tenantId` partition for batch operations
- Cross-entity changes are orchestrated via an `operation` + Functions saga

---

## Core Workflows (MVP)

1) Create Tenant
- Create `tenants` doc, validate placement, default routing
- Emit `TenantCreated` event

2) Update Routing
- Change routing.strategy/weights/baseDomain
- Validate policy/compliance; emit `RouteUpdated`

3) Migrate Tenant (shared → dedicated or cell → cell)
- Create `operations` doc with steps: provisionTarget → syncData → drainAndCutover → validate
- Functions orchestrates; UI shows step status; emit `Migration*` events

4) Suspend/Resume/Maintenance
- Flip status; adjust routing/traffic; emit `TenantStatusUpdated`

5) Decommission Tenant
- Archive/export per policy; emit `TenantDecommissioned`

---

## Security & Access Control

- Entra ID auth with App Roles:
  - Platform.Admin: full access
  - Operator: execute operations, update routing; no delete
  - Reader: read-only
- DAB permissions aligned to roles; Functions enforce command RBAC

---

## Domain naming and global uniqueness

- Test framework (this repo): No global domain reservation is required. Use platform-provided base domains (for example, the default Azure Container Apps hostname or function host domain) during development and testing.
- Production recommendation: Implement a global domain reservation to guarantee uniqueness across all tenants.
  - Why: Cosmos DB unique keys are enforced per-partition. With tenant-scoped partitions (e.g., pk = /tenantId), a naive unique key on domain won’t prevent duplicates globally.
  - Pattern: Use a central registry (e.g., Cosmos container `catalogs` with pk `/type`, item `{ id: <domain>, type: "domains" }`) or an alternate authoritative store. Reserve before tenant creation; release on decommission.
  - API enforcement: Expose a reservation endpoint/mutation; on conflict, return a 409-like error and block tenant creation. Make the operation idempotent and include retries.
  - Ops: Include cleanup tooling for orphaned reservations and audit who reserved which domains.

Note: Sample UI and schema in this repo show how a reservation could work, but it’s optional for the test framework. Adopt the reservation flow when promoting to production to avoid domain collisions.

---

## Deployment Topology

- Resource Group: `rg-stamps-mgmt-<env>`
- Services
  - Azure Container Apps Environment (global mgmt)
  - Container App: Blazor Portal
  - Container App: DAB API (preferred). App Service optional alternative if required.
  - Azure Functions (Consumption/Premium) for command handlers
  - Cosmos DB account + DB + containers
  - Event Grid topic (optional initially)
  - Application Insights

---

## Infra Parameters (excerpt)

- cosmosAccountName, dbName = stamps-control-plane
- containers: tenants, cells, operations, catalogs
- containerAppsEnvName
- blazorImage (if containerized), dabImage (or run via dotnet)
- insightsName, eventGridTopicName
- managed identities and RBAC assignments

---

## Tech Decisions

- UI: Blazor Server (interactive) for rapid admin UX, Bootstrap 5 via libman/CDN
- Data API: DAB for fast GraphQL; custom endpoints via Functions for commands
- Cosmos consistency: Session for UI reads; command writes with retries+ETag
- Eventing: Event Grid to decouple infra actions

---

## Folder Structure (planned)

```
management-portal/
  src/
    Portal/                 # Blazor .NET 9
    DAB.Api/                # Data API Builder host + dab-config.json
    Functions/              # Command handlers (optional in v1)
  infra/
    managementLayer.bicep   # ACA, Cosmos, DAB, App Insights, identities
  docs/
    USER_GUIDE.md           # How to onboard/manage tenants
```

---

## Milestones & Acceptance Criteria

M1: Scaffolding & Infra (ACA + Cosmos + DAB)
- [ ] Repo structure created
- [ ] DAB configured for `tenants`, `cells`, `operations`
- [ ] Bicep to deploy Cosmos + ACA + App Insights

M2: UI MVP (Tenants & Cells)
- [ ] Tenants list/detail (read from GraphQL)
- [ ] Cells list/detail
- [ ] Bootstrap 5 styling, auth wired

M3: Operations (Migration Flow)
- [ ] Create migration operation (UI → Functions)
- [ ] Step status updates & audit trail

M4: Hardening & Docs
- [ ] RBAC tuned, diagnostics/dashboards
- [ ] USER_GUIDE complete, operator runbooks

---

## Risks & Mitigations

- Cross-partition updates → use operation saga pattern
- Consistency/read-your-writes → prefer Session + retries; surface in UI
- Capacity limits in ACA/Cosmos → autoscale profiles, alerts
- Security drift → App roles + least privilege + periodic reviews

---

## Next Actions (you are here)

- Confirm Container Apps hosting and Bootstrap 5 (done)
- Create repo folders and placeholder files
- Draft Bicep skeleton and dab-config.json outline
- Start Blazor skeleton with auth and Bootstrap 5 imports


