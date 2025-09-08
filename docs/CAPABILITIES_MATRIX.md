# Capabilities Matrix

## 📘 Capability Readiness Guide
Comprehensive view of functional, operational, and governance capabilities in the Azure Stamps Pattern. Use this to assess readiness, identify gaps, and prioritize roadmap work.

---
## 🧭 Quick Navigation

| Section | Focus Area | Best for |
|---------|------------|----------|
| [📊 Status Legend](#-status-legend) | Status meaning & usage | All readers |
| [🏗 Infrastructure & Orchestration](#-infrastructure--orchestration) | Core templates & provisioning | Cloud Engineers |
| [🌐 Networking & Ingress](#-networking--ingress) | Global/regional routing & edge | Network / Platform |
| [⚙️ Compute & Runtime](#️-compute--runtime) | Workload hosting options | Architects, Devs |
| [🔐 Identity & Access](#-identity--access) | AuthN/AuthZ & secrets | Security, Platform |
| [🧩 Tenant Lifecycle & Management](#-tenant-lifecycle--management) | Provisioning & migration | Product / Ops |
| [🗄️ Data Layer & Strategy](#️-data-layer--strategy) | Partitioning & governance | Data / Architecture |
| [🛡️ Security & Compliance](#️-security--compliance) | Controls & policy baseline | Security / Compliance |
| [📈 Observability & Operations](#-observability--operations) | Monitoring & runbooks | SRE / Ops |
| [♻️ Scalability & Resilience](#️-scalability--resilience) | HA / DR / scale patterns | Architects / SRE |
| [💰 Cost Management & Optimization](#-cost-management--optimization) | FinOps & chargeback | Finance / Platform |
| [🚀 DevOps & Delivery](#-devops--delivery) | CI/CD & release process | DevOps |
| [🖥️ Application Layer (GraphQL & Portal)](#️-application-layer-graphql--portal) | Control-plane experience | App Teams |
| [📏 Governance & Standards](#-governance--standards) | Conventions & consistency | Architecture Board |
| [🔮 Future / Roadmap Themes](#-future--roadmap-themes) | Upcoming enhancements | Leadership |
| [🧮 Summary Assessment](#-summary-assessment) | Overall posture | Executives |
| [🎯 Recommended Next 5 Priorities](#-recommended-next-5-priorities) | Immediate focus | Steering Group |

---
## 📊 Status Legend

| Status | Meaning |
|--------|---------|
| Implemented | In repo, deployable, validated in sample environment |
| Partial | Exists but missing depth / hardening |
| In Progress | Actively being built/refactored |
| Planned | On near-term roadmap |
| Deferred | Intentionally postponed |

---
## 🏗 Infrastructure & Orchestration
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Multi-layer Bicep (global/regional/CELL) | Implemented | Core loops stable | `main.bicep`, `regionalLayer.bicep`, `deploymentStampLayer.bicep` |
| Hub / Host split deployment | Implemented | Dual-subscription example present | `hub-main.bicep`, `host-main.bicep` |
| Parameterized geo/region/cell model | Implemented | Supports variable AZ counts | `main.parameters.json` |
| Naming conventions standardization | Partial | Guide exists; some resources still ad‑hoc | `NAMING_CONVENTIONS_GUIDE.md` |
| Infrastructure drift detection | Planned | Consider deployment what-if + GitHub Action | (none) |
| Infrastructure testing (preflight) | Planned | Add PS/Pester or Bicep linter gate | (none) |

## 🌐 Networking & Ingress
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Global routing (Front Door / Traffic Manager) | Implemented | Both options described; sample wiring | `globalLayer.bicep` |
| Regional ingress (App Gateway WAF) | Implemented | Zone-redundant guidance present | `regionalLayer.bicep` |
| Private endpoints (data services) | Partial | Stated as strategy; enforcement policy TBD | `security` bicep modules |
| DNS automation | Planned | Manual zones presently | (none) |
| Cross-region failover routing playbook | Planned | Document partial; needs runbook | `DISASTER_RECOVERY_GUIDE.md` (if added later) |

## ⚙️ Compute & Runtime
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| CELL compute abstraction (Functions/AppSvc/Container Apps/AKS options) | Implemented | Decision guidance included | `ARCHITECTURE_GUIDE.md` |
| Container Apps baseline | Implemented | Example images and scaling | `deploymentStampLayer.bicep` |
| AKS optional path | Planned | Strategy referenced; not scripted | (none) |
| Background jobs / schedulers | Planned | Could use Functions timers | (none) |
| Multi-runtime polyglot support | Partial | Conceptual; single language sample | (none) |

## 🔐 Identity & Access
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Managed identities (system/user-assigned) | Implemented | Used in templates | `managedIdentity.bicep` |
| External tenant (Microsoft Entra External ID customers) integration | Partial | Manual setup documented; automation not possible | `PROBLEM_STATEMENT.md`, whitepaper notes |
| RBAC role assignments (least privilege) | Partial | Some broad assignments; needs tightening | `globalIdentityRoleAssignment.sub.bicep` |
| Key Vault secret referencing | Implemented | Used; recommendation to replace inline secrets | `keyvault.bicep` |
| JWT validation optimization (JWKS caching) | Planned | Mentioned in perf notes; code hook TBD | (none) |

## 🧩 Tenant Lifecycle & Management
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Tenant provisioning function | Implemented | `CreateTenantFunction` | `CreateTenantFunction.cs` |
| Tenant CELL resolution | Implemented | `GetTenantCellFunction` | `GetTenantCellFunction.cs` |
| User assignment to tenant | Implemented | `AddUserToTenantFunction` | `AddUserToTenantFunction.cs` |
| Tenant migration (shared → dedicated) | Partial | Documented procedure; automation scripts absent | Whitepaper, Architecture Guide |
| Tenant deletion / deprovision | Planned | Needs data retention policy integration | (none) |
| Tenant quota & throttling policy | Planned | Implement via APIM tier policies | `apimInstance.bicep` |

## 🗄️ Data Layer & Strategy
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Global tenant directory (Cosmos DB) | Implemented | Index policy included | `cosmos-indexing-policy.json` |
| Shared vs dedicated SQL tenancy | Implemented | Guidance provided | Guides |
| Data partitioning & RLS strategy | Partial | Conceptual; sample RLS DDL missing | `DATA_STRATEGY_GUIDE.md` |
| Data migration tooling references | Partial | DMS/Data Factory noted; scripts absent | Guides |
| Analytics / Synapse integration | Planned | Outlined only | `DATA_STRATEGY_GUIDE.md` |
| Purview governance integration | Planned | Future compliance enhancement | (none) |
| Backup & restore procedures | Planned | Need runbook + automation | (none) |

## 🛡️ Security & Compliance
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| CAF/WAF alignment scoring | Implemented | Score documented | `CAF_WAF_COMPLIANCE_ANALYSIS.md` |
| Zero-trust baseline (private endpoints, no public DB) | Partial | Enforcement policies incomplete | Security bicep |
| Policy as Code modules | Implemented | Deployed in templates | `policyAsCode.bicep` |
| WAF (Front Door/App Gateway) | Implemented | Included | `frontdoor-standalone.bicep` |
| Secrets management (KV) | Implemented | Encouraged standard | `keyvault.bicep` |
| Key rotation / certificate automation | Planned | Add automation runbooks | (none) |
| Threat detection (Defender Plans) | Implemented | Plans provisioned | `defenderPlans.bicep` |
| Zero-trust conditional access articulation | Partial | Documented; not codified | Guides |
| Audit logging completeness | Partial | Need matrix of log sources | (none) |

## 📈 Observability & Operations
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Log Analytics (global & regional workspaces) | Implemented | Wiring present | `monitoringLayer.bicep` |
| Custom dashboards | Implemented | Provided via dashboards bicep | `monitoringDashboards.bicep` |
| Centralized tracing strategy | Partial | Concept described; no OpenTelemetry wiring | (none) |
| Alerting standards | Planned | Define severity matrix | (none) |
| Runbook automation | Planned | Target Automation Account | (none) |
| Performance profiling guidance | Partial | Some latency tables; tooling missing | Whitepaper |

## ♻️ Scalability & Resilience
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Horizontal scaling by CELL addition | Implemented | Documented in guides | Guides |
| Availability Zone selectable deployment | Implemented | Zone arrays supported | Bicep templates |
| Active/Active multi-region strategy | Partial | Conceptual; traffic policies examples missing | Whitepaper |
| DR failover runbook | Planned | Needs procedural doc | (none) |
| Autoscale (compute) | Implemented | Container Apps autoscale examples | Bicep |
| Autoscale (Cosmos RU) | Planned | Add autoscale param defaults | (none) |
| Caching layer (Redis) integration | Planned | Mentioned; not provisioned | (none) |

## 💰 Cost Management & Optimization
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Mixed tenancy cost model | Implemented | Shared vs dedicated economics stated | Whitepaper |
| Cost allocation per CELL | Partial | Need tagging standard summary | `resourceGroups.bicep` |
| Reserved capacity planning guidance | Planned | For SQL/Cosmos | (none) |
| Autoscale cost impact modeling | Planned | Add FinOps appendix | (none) |

## 🚀 DevOps & Delivery
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| CI image build & push | Implemented | Basic workflow present | GitHub Actions (not in docs folder) |
| OIDC federation (secrets minimization) | Planned | Recommend replacing service principals | (none) |
| Multi-env promotion strategy | Planned | Dev/Test/Prod pipeline doc | (none) |
| Release versioning / tagging | Partial | Manual version metadata | CHANGELOG |
| Infrastructure validation pipeline (lint) | Planned | Add Bicep linter action | (none) |

## 🖥️ Application Layer (GraphQL & Portal)
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Hot Chocolate GraphQL layer | Implemented | Re-baselined from DAB | Portal repo section |
| Management Portal (Blazor) | Implemented | Integrates GraphQL | `Management Portal` folder |
| DAL optimization (JWKS caching, batching) | Planned | Performance section notes only | (none) |
| API Management policy set (tenant throttling) | Partial | Baseline; advanced tiering pending | `apimInstance.bicep` |

## 📏 Governance & Standards
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Tagging strategy enforcement | Partial | Tag schema not fully listed | (none) |
| Documentation cross-linking | Implemented | Reciprocal links added | Docs |
| Glossary consistency | Implemented | Maintained | `GLOSSARY.md` |
| Decision records (ADR style) | Deferred | Could add for major tradeoffs | (none) |
| Compliance evidence packaging | Planned | Provide export script | (none) |

## 🔮 Future / Roadmap Themes
| Theme | Intent | Status |
|-------|--------|:------:|
| AI Ops (predictive scaling, anomaly) | Integrate ML for proactive scaling | Planned |
| Automated tenant migration tooling | Scripted shared→dedicated move | Planned |
| RLS + sample DB schema pack | Provide ready SQL artifacts | Planned |
| Full private networking (no public ingress except edge) | Lock down lateral movement | In Progress |
| Redis + CDN caching strategy | Reduce DB and egress costs | Planned |
| Observability unification (OpenTelemetry) | Distributed tracing standard | Planned |

---
## 🧮 Summary Assessment
**Overall Posture:** Core architectural spine is strong and deployable; maturity gaps are concentrated in operational automation, deep data governance, and advanced resilience.

| Domain | Strengths | Gaps / Risks | Action Signal |
|--------|-----------|--------------|---------------|
| Architecture Core | Layered Bicep, tenancy mix, AZ support | Drift detection absent | Add infra validation pipeline |
| Data | Partitioning guidance, directory model | No RLS sample pack; no backup runbook | Provide reference schema + RLS DDL |
| Security | WAF, Defender plans, KV usage | Private endpoint enforcement partial | Expand policy set (deny public data endpoints) |
| Operations | Dashboards + logging baseline | No DR/runbook automation | Author failover & recovery runbooks |
| Identity | Managed identities wired | Broad RBAC scopes in places | Tighten least‑privilege roles |
| Cost | Mixed tenancy model defined | No automated tagging enforcement | Tag governance & cost export script |
| Resilience | Horizontal CELL scaling | Active/Active patterns not codified | Traffic policy examples + drills |
| DevEx / Delivery | Basic CI/build working | No lint / policy gate in pipeline | Add Bicep linter + what-if stage |
| Governance | Cross-linking & glossary stable | No ADRs / decision history | Introduce lightweight ADR template |

### ✅ Strength Anchors
- Deployable multi-layer infra with clear geo/region/cell abstraction.
- Tenancy flexibility (shared → dedicated) without redesign.
- Observability scaffold (dashboards, workspaces, baseline metrics) in place.
- Security baseline (WAF + Defender + managed identity) consistently applied.

### ⚠️ Material Gaps
- Disaster recovery and failover procedures undocumented (runbook debt).
- Data governance depth (RLS, Purview, backup/restore) not yet implemented.
- Cost allocation model lacks enforced tagging standard; opaque chargeback risk.
- Active/Active multi-region strategy conceptual only—no executable policy examples.
- RBAC and private endpoint enforcement require policy tightening for least privilege / zero trust.

### 🧪 Emerging Risks (If Deferred)
- Incident MTTR elongates without DR playbooks (operational fragility).
- Compliance audit friction increases without data governance artifacts.
- Cloud spend variance grows without tagging & RU autoscale defaults.
- Performance regression risk if GraphQL/DAL optimizations (JWKS caching, batching) remain theoretical.

### 📌 Near-Term Leverage Points
- Add automated footer/version + tagging policy to drive consistency.
- Ship a minimal DR exercise (tabletop + documented steps) before scaling regions.
- Provide a reference SQL schema + RLS snippets to unblock secure shared tenancy adoption.
- Introduce OpenTelemetry collector path to unify tracing early (avoids retrofit cost).
