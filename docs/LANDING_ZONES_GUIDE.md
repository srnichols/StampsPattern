# 🏗️ Azure Stamps Pattern - Azure Landing Zones Guide

Practical guide to placing Azure Stamps Pattern components within Azure Landing Zones - platform versus workload boundaries, management group hierarchy, policy guardrails, and IaC entry points - so you can scale safely with clear ownership and governance.

- What's inside: MG hierarchy, subscription design, component-to-LZ mapping, policy assignments, networking, identity, monitoring, and IaC wiring
- Best for: Platform/ALZ teams, solution architects, DevOps/infra engineers, and security/governance leads
- Outcomes: Clear placement rules, repeatable deployments, consistent guardrails, and reduced blast radius

## 👤 Who Should Read This Guide?

- Platform/ALZ Teams: Define and operate CAF-aligned landing zones and guardrails
- Solution Architects: Map workload components to the right scopes (MG, subscription)
- DevOps/Infra Engineers: Implement IaC with correct scoping and parameters
- Security/Governance: Enforce policy-as-code and central diagnostics at scale

---

## 🧭 Quick Navigation

| Section | Focus Area | Time to Read | Best for |
|---------|------------|--------------|----------|
| [🗂️ MGs & Subscriptions](#-management-groups-and-subscriptions) | CAF hierarchy and scope | 7 min | Platform, Architects |
| [🧩 Component Mapping](#-component-to-landing-zone-mapping) | Where each piece belongs | 10 min | Architects, DevOps |
| [🛡️ Governance & Policy](#-governance--policy) | Initiatives, diagnostics, guardrails | 8 min | Platform, Security |
| [🌐 Networking & Connectivity](#-networking--connectivity) | Hub/spoke, private DNS, vWAN | 7 min | Network, DevOps |
| [🔐 Identity & Access](#-identity--access) | RBAC, PIM, managed identities | 5 min | Security, Platform |
| [📈 Monitoring & Security](#-monitoring--security) | LAW, Defender, Sentinel | 6 min | Ops, Security |
| [🚀 CI/CD & Environments](#-cicd--environments) | Pipelines and scopes | 5 min | DevOps |
| [🏗️ IaC Structure & Parameters](#-iac-structure--parameters) | Scoping modules and params | 6 min | DevOps |
| [🏷️ Tags, Cost, and Quotas](#-tags-cost-and-quotas) | Standards and limits | 5 min | IT Leaders |

Last updated: August 2025

## 🧭 Where Things Go

- Platform landing zones host shared enterprise services: Identity (process), Management, Connectivity, and Shared Services (global edge, shared gateways). Do not put all infra into the Management subscription.
- Application (workload) landing zones host your CELLs (shared or dedicated) per region. Use one subscription per CELL for isolation, quotas, and billing clarity.
- Control Plane (management portal, DAB GraphQL, control metadata): either a) Platform Shared-Services subscription if used by many apps/org-wide, or b) a dedicated “ControlPlane” workload subscription under Landing Zones for autonomy and SDLC separation.

### 🖼️ Visual: High-Level Placement

```mermaid
%%{init: {"theme":"base","themeVariables":{"background":"transparent","primaryColor":"#E6F0FF","primaryTextColor":"#1F2937","primaryBorderColor":"#94A3B8","lineColor":"#94A3B8","secondaryColor":"#F3F4F6","tertiaryColor":"#DBEAFE","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","edgeLabelBackground":"#F8FAFC","fontFamily":"Segoe UI, Roboto, Helvetica, Arial, sans-serif"}} }%%
graph LR
  platform["Platform / Shared-Services"] --- fd["Front Door / Traffic Manager"]
  platform --- apim["APIM (Global)"]
  platform --- control["Control Plane"]
  lz["Landing Zones (Workloads)"] --- cell_shared["CELL Subscriptions"]
  lz --- cell_ded["Per-Tenant Dedicated CELLs"]
  fd --> cell_shared
  fd --> cell_ded
  apim --> cell_shared
  apim --> cell_ded
  control -.-> cell_shared
  control -.-> cell_ded
```

Caption: High-level placement of global edge, control plane, and CELL subscriptions across landing zones.

---

## 🗂️ Management Groups and Subscriptions

Recommended CAF-aligned hierarchy:

```
Tenant Root Group (TRG)
├─ Platform (MG)
│  ├─ Identity (process-owned; Entra ID tenant scope)
│  ├─ Management (subscription)
│  ├─ Connectivity (subscription)
│  └─ Shared-Services (subscription)
└─ Landing Zones (MG)
   ├─ Corp (MG)
   │  ├─ Sub: corp-dev
   │  ├─ Sub: corp-test
   │  └─ Sub: corp-prod
   ├─ Online (MG)
   │  ├─ Sub: online-eus-cell-shared-z2
   │  ├─ Sub: online-weu-cell-shared-z2
   │  └─ Sub: online-eus-cell-dedicated-tenantX
   └─ Sandbox (MG)
      └─ Sub: sandbox
```

### 🖼️ Visual: MG Hierarchy (CAF-Aligned)

```mermaid
%%{init: {"theme":"base","themeVariables":{"background":"transparent","primaryColor":"#E6F0FF","primaryTextColor":"#1F2937","primaryBorderColor":"#94A3B8","lineColor":"#94A3B8","secondaryColor":"#F3F4F6","tertiaryColor":"#DBEAFE","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","edgeLabelBackground":"#F8FAFC","fontFamily":"Segoe UI, Roboto, Helvetica, Arial, sans-serif"}} }%%
graph TD
  trg["TRG"] --> platform_mg["Platform MG"]
  trg --> lz_mg["Landing Zones MG"]
  platform_mg --> mgmt_sub["Management Sub"]
  platform_mg --> conn_sub["Connectivity Sub"]
  platform_mg --> ss_sub["Shared-Services Sub"]
  lz_mg --> corp_mg["Corp MG"]
  lz_mg --> online_mg["Online MG"]
  lz_mg --> sandbox_mg["Sandbox MG"]
  online_mg --> workload_cells["Workload Cell Subscriptions"]
```

Caption: CAF-aligned management group hierarchy and subscription layout.

### 📦 Subscriptions at a Glance

- Platform/Management: Log Analytics, Sentinel, Defender, Automation; central diagnostics.
- Platform/Connectivity: vWAN/Hub VNets, Azure Firewall, Private DNS, DDoS plan.
- Platform/Shared-Services: Traffic Manager, Front Door, global APIM (if shared), optional Control Plane.
- Workload (Application) landing zones: CELL per subscription; VNet-injected Container Apps Env, App Gateway, Redis, SQL, Storage, per-CELL Key Vault, Private Endpoints.

---

## 🧩 Component-to-Landing-Zone Mapping

| Component (repo) | Resource examples | Landing zone | Rationale |
|---|---|---|---|
| Global Layer (traffic-routing.bicep) | Traffic Manager, Front Door | Platform/Shared-Services | Global edge, shared across workloads |
| Geodes/Global Control Plane (globalLayer.bicep, b2c-setup.bicep) | APIM (global), B2C, Control Plane Cosmos (if shared) | Platform/Shared-Services (or dedicated ControlPlane workload sub) | Central governance & reuse |
| Regional Layer (regionalLayer.bicep) | App Gateway, Key Vault, Automation | Platform/Connectivity (shared) or per-workload if required | Regional entry, shared networking |
| CELL Layer (deploymentStampLayer.bicep, geodesLayer.bicep) | Container Apps Env and apps, Redis, SQL/Storage, KV, Private Endpoints | Application/Workload LZ (per-CELL subscription) | Isolation, quotas, billing |
| Management Portal (management-portal) | Blazor Server app, DAB GraphQL, control-plane Cosmos DB | Platform/Shared-Services or dedicated ControlPlane workload sub | Org-wide mgmt or app autonomy |
| Monitoring (monitoringLayer.bicep, monitoringDashboards.bicep) | Log Analytics, Dashboards, alerts | Platform/Management (central) + per-CELL in workload subs | Central visibility + local SLOs |
| Security/Policy (policyAsCode.bicep, zeroTrustSecurity.bicep) | Policy assignments, Defender, Sentinel | MG scopes (Platform, Landing Zones) | Inheritance and guardrails |

---

## 🛡️ Governance & Policy

- Apply policy at MG scope; inherit to subscriptions. At minimum:
  - Required: Diagnostic settings to Log Analytics, Defender for Cloud on, baseline tag requirements, allowed locations/SKUs, secure transfer, TLS minimums, managed identity enforced.
  - Workload MG: allow list of PaaS services, regional/AZ constraints, Private Endpoint requirement for data services.
- Use your `policyAsCode.bicep` to assign initiatives at MG scope. Example (Bicep):

```bicep
targetScope = 'managementGroup'

@description('ID of the management group (e.g., platform or landingzones)')
param mgId string

module diagnostics './policy/assign-diagnostics.bicep' = {
  name: 'assign-diagnostics'
  scope: managementGroup(mgId)
  params: {
    logAnalyticsResourceId: resourceId('/subscriptions/<mgmt-sub-id>/resourceGroups/rg-mgmt/providers/Microsoft.OperationalInsights/workspaces/law-central')
  }
}
```

---

## 🌐 Networking & Connectivity

- Hub-and-spoke or vWAN in Platform/Connectivity subscription.
- Private DNS zones central in hub; link CELL spokes across subscriptions.
- Container Apps: use VNet-injected CAE in each CELL subscription; ensure hub-spoke peering/vWAN route propagation and Private DNS resolution.
- Private Endpoints for SQL/Storage/etc. in CELL spokes; integrate with central Private DNS.

---

## 🔐 Identity & Access

- Entra ID tenant-level ownership for identity; PIM-enforced RBAC.
- Platform team owns Platform subscriptions; workload teams own CELL subscriptions.
- Managed identities everywhere (Functions/Apps/APIM/CAE); separate Key Vault per CELL; platform KV for shared secrets.

---

## 🧭 Monitoring & Security

- Central Log Analytics workspace(s) in Platform/Management; optional per-CELL workspaces for autonomy.
- Defender for Cloud enabled across Platform and Landing Zones; Sentinel in Management.
- Standardize diagnostic settings via policy; use workbooks/dashboards (see `monitoringDashboards.bicep`).

---

## 🚀 CI/CD & Environments

- Platform pipelines (infrequent): Management/Connectivity/Shared-Services; policy assignments at MG.
- Workload pipelines (frequent): deploy stamps (CELLs) to workload subscriptions; parameterize subscription IDs and regions.
- Separate MGs or folders per env (dev/test/prod); align subscriptions accordingly.

---

## 🏗️ IaC Structure & Parameters

- Keep Bicep modules layer-aligned (already reflected in repo). Parameterize:
  - platformSubscriptionId, connectivitySubscriptionId, sharedServicesSubscriptionId
  - cellSubscriptionId, region, azZone, environment, cellId
- Example (Bicep entry-point):

```bicep
param platformSubId string
param sharedServicesSubId string
param cellSubId string
param region string
param cellId string

// Global edge
module global './traffic-routing.bicep' = {
  name: 'global-edge'
  scope: subscription(sharedServicesSubId)
  params: {
    // ... your params
  }
}

// Control plane (optional centralized)
module controlPlane './AzureArchitecture/globalLayer.bicep' = {
  name: 'control-plane'
  scope: subscription(sharedServicesSubId)
  params: {
    // ... your params
  }
}

// CELL in workload subscription
module cell './AzureArchitecture/deploymentStampLayer.bicep' = {
  name: 'cell-' + cellId
  scope: subscription(cellSubId)
  params: {
    location: region
    cellId: cellId
    // ... your params
  }
}
```

---

## 🏷️ Tags, Cost, and Quotas

- Standard tags: `env`, `costCenter`, `owner`, `app`, `cellId`, `tenantId`, `azd-env-name`.
- Budgets at subscription level per CELL; cost analysis by tag.
- Dedicated CELLs per enterprise tenant ease chargeback and increase quota limits vs shared.

---

## 🛟 Resiliency & DR

- Global: Front Door/Traffic Manager (active-active across regions).
- Regional: duplicate CELLs across at least two regions; align data replication (SQL/Cosmos) to RPO/RTO.
- Control Plane: geo-replicate Cosmos DB (if used centrally) and deploy portal/DAB in two regions.

---

## ✅ Quick Decisions Checklist

- [ ] Control Plane placement: Platform Shared-Services vs dedicated workload subscription
- [ ] Per-CELL subscription model: shared vs dedicated per enterprise tenant
- [ ] Hub/spoke or vWAN topology; Private DNS ownership location
- [ ] Single vs dual Log Analytics strategy; Sentinel enabled
- [ ] Region pairs and DR pattern; target RPO/RTO
- [ ] Policy initiatives at Platform and Landing Zones MGs

---

## 🧰 Implementation Starters

Starter Bicep templates are available under `infra/alz-starter/`:

- `mg-policy-assign.bicep` — Minimal management group policy/initiative assignment.
- `subscription-map.bicep` — Tenant-scope subscription mapping for platform/shared services and cells.

These are conservative, non-destructive starters you can extend with your own policy sets and subscription provisioning.

### 🖼️ Visual: IaC Flow (Consumer View)

```mermaid
%%{init: {"theme":"base","themeVariables":{"background":"transparent","primaryColor":"#E6F0FF","primaryTextColor":"#1F2937","primaryBorderColor":"#94A3B8","lineColor":"#94A3B8","secondaryColor":"#F3F4F6","tertiaryColor":"#DBEAFE","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","edgeLabelBackground":"#F8FAFC","fontFamily":"Segoe UI, Roboto, Helvetica, Arial, sans-serif"}} }%%
flowchart LR
  params["Parameters (IDs, Regions)"] --> entry["Entry Bicep"]
  entry --> global_mod["Global Edge Module"]
  entry --> control_mod["Control Plane Module"]
  entry --> cell_mod["Cell Module"]
  cell_mod --> sub_target["Workload Subscription"]
```

---

## 📚 Related Guides

- [Architecture Guide](./ARCHITECTURE_GUIDE.md)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)
- [Security Guide](./SECURITY_GUIDE.md)
- [Parameterization Guide](./PARAMETERIZATION_GUIDE.md)
- [Naming Conventions](./NAMING_CONVENTIONS_GUIDE.md)
- [Glossary](./GLOSSARY.md)
- [Known Issues](./KNOWN_ISSUES.md)
- [Cost Optimization](./COST_OPTIMIZATION_GUIDE.md)

- Azure CAF – Landing Zones: <a href="https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/" target="_blank" rel="noopener">docs</a>
- Azure Architecture Center: <a href="https://learn.microsoft.com/azure/architecture/" target="_blank" rel="noopener">docs</a>
- Repo docs: `ARCHITECTURE_GUIDE.md`, `OPERATIONS_GUIDE.md`, `SECURITY_GUIDE.md`, `NAMING_CONVENTIONS_GUIDE.md`
