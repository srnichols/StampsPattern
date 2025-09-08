# Capabilities Matrix

Comprehensive view of functional, operational, and governance capabilities in the Azure Stamps Pattern. Use this to assess readiness, identify gaps, and prioritize roadmap work.

## Status Legend

| Status | Meaning |
|--------|---------|
| Implemented | In repo, deployable, validated in sample environment |
| Partial | Exists but missing depth / hardening |
| In Progress | Actively being built/refactored |
| Planned | On near-term roadmap |
| Deferred | Intentionally postponed |

---
## 1. Infrastructure & Orchestration
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Multi-layer Bicep (global/regional/CELL) | Implemented | Core loops stable | `main.bicep`, `regionalLayer.bicep`, `deploymentStampLayer.bicep` |
| Hub / Host split deployment | Implemented | Dual-subscription example present | `hub-main.bicep`, `host-main.bicep` |
| Parameterized geo/region/cell model | Implemented | Supports variable AZ counts | `main.parameters.json` |
| Naming conventions standardization | Partial | Guide exists; some resources still ad‑hoc | `NAMING_CONVENTIONS_GUIDE.md` |
| Infrastructure drift detection | Planned | Consider deployment what-if + GitHub Action | (none) |
| Infrastructure testing (preflight) | Planned | Add PS/Pester or Bicep linter gate | (none) |

## 2. Networking & Ingress
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Global routing (Front Door / Traffic Manager) | Implemented | Both options described; sample wiring | `globalLayer.bicep` |
| Regional ingress (App Gateway WAF) | Implemented | Zone-redundant guidance present | `regionalLayer.bicep` |
| Private endpoints (data services) | Partial | Stated as strategy; enforcement policy TBD | `security` bicep modules |
| DNS automation | Planned | Manual zones presently | (none) |
| Cross-region failover routing playbook | Planned | Document partial; needs runbook | `DISASTER_RECOVERY_GUIDE.md` (if added later) |

## 3. Compute & Runtime
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| CELL compute abstraction (Functions/AppSvc/Container Apps/AKS options) | Implemented | Decision guidance included | `ARCHITECTURE_GUIDE.md` |
| Container Apps baseline | Implemented | Example images and scaling | `deploymentStampLayer.bicep` |
| AKS optional path | Planned | Strategy referenced; not scripted | (none) |
| Background jobs / schedulers | Planned | Could use Functions timers | (none) |
| Multi-runtime polyglot support | Partial | Conceptual; single language sample | (none) |

## 4. Identity & Access
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Managed identities (system/user-assigned) | Implemented | Used in templates | `managedIdentity.bicep` |
| External tenant (Microsoft Entra External ID customers) integration | Partial | Manual setup documented; automation not possible | `PROBLEM_STATEMENT.md`, whitepaper notes |
| RBAC role assignments (least privilege) | Partial | Some broad assignments; needs tightening | `globalIdentityRoleAssignment.sub.bicep` |
| Key Vault secret referencing | Implemented | Used; recommendation to replace inline secrets | `keyvault.bicep` |
| JWT validation optimization (JWKS caching) | Planned | Mentioned in perf notes; code hook TBD | (none) |

## 5. Tenant Lifecycle & Management
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Tenant provisioning function | Implemented | `CreateTenantFunction` | `CreateTenantFunction.cs` |
| Tenant CELL resolution | Implemented | `GetTenantCellFunction` | `GetTenantCellFunction.cs` |
| User assignment to tenant | Implemented | `AddUserToTenantFunction` | `AddUserToTenantFunction.cs` |
| Tenant migration (shared → dedicated) | Partial | Documented procedure; automation scripts absent | Whitepaper, Architecture Guide |
| Tenant deletion / deprovision | Planned | Needs data retention policy integration | (none) |
| Tenant quota & throttling policy | Planned | Implement via APIM tier policies | `apimInstance.bicep` |

## 6. Data Layer & Strategy
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Global tenant directory (Cosmos DB) | Implemented | Index policy included | `cosmos-indexing-policy.json` |
| Shared vs dedicated SQL tenancy | Implemented | Guidance provided | Guides |
| Data partitioning & RLS strategy | Partial | Conceptual; sample RLS DDL missing | `DATA_STRATEGY_GUIDE.md` |
| Data migration tooling references | Partial | DMS/Data Factory noted; scripts absent | Guides |
| Analytics / Synapse integration | Planned | Outlined only | `DATA_STRATEGY_GUIDE.md` |
| Purview governance integration | Planned | Future compliance enhancement | (none) |
| Backup & restore procedures | Planned | Need runbook + automation | (none) |

## 7. Security & Compliance
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

## 8. Observability & Operations
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Log Analytics (global & regional workspaces) | Implemented | Wiring present | `monitoringLayer.bicep` |
| Custom dashboards | Implemented | Provided via dashboards bicep | `monitoringDashboards.bicep` |
| Centralized tracing strategy | Partial | Concept described; no OpenTelemetry wiring | (none) |
| Alerting standards | Planned | Define severity matrix | (none) |
| Runbook automation | Planned | Target Automation Account | (none) |
| Performance profiling guidance | Partial | Some latency tables; tooling missing | Whitepaper |

## 9. Scalability & Resilience
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Horizontal scaling by CELL addition | Implemented | Documented in guides | Guides |
| Availability Zone selectable deployment | Implemented | Zone arrays supported | Bicep templates |
| Active/Active multi-region strategy | Partial | Conceptual; traffic policies examples missing | Whitepaper |
| DR failover runbook | Planned | Needs procedural doc | (none) |
| Autoscale (compute) | Implemented | Container Apps autoscale examples | Bicep |
| Autoscale (Cosmos RU) | Planned | Add autoscale param defaults | (none) |
| Caching layer (Redis) integration | Planned | Mentioned; not provisioned | (none) |

## 10. Cost Management & Optimization
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Mixed tenancy cost model | Implemented | Shared vs dedicated economics stated | Whitepaper |
| Cost allocation per CELL | Partial | Need tagging standard summary | `resourceGroups.bicep` |
| Reserved capacity planning guidance | Planned | For SQL/Cosmos | (none) |
| Autoscale cost impact modeling | Planned | Add FinOps appendix | (none) |

## 11. DevOps & Delivery
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| CI image build & push | Implemented | Basic workflow present | GitHub Actions (not in docs folder) |
| OIDC federation (secrets minimization) | Planned | Recommend replacing service principals | (none) |
| Multi-env promotion strategy | Planned | Dev/Test/Prod pipeline doc | (none) |
| Release versioning / tagging | Partial | Manual version metadata | CHANGELOG |
| Infrastructure validation pipeline (lint) | Planned | Add Bicep linter action | (none) |

## 12. Application Layer (GraphQL & Portal)
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Hot Chocolate GraphQL layer | Implemented | Re-baselined from DAB | Portal repo section |
| Management Portal (Blazor) | Implemented | Integrates GraphQL | `Management Portal` folder |
| DAL optimization (JWKS caching, batching) | Planned | Performance section notes only | (none) |
| API Management policy set (tenant throttling) | Partial | Baseline; advanced tiering pending | `apimInstance.bicep` |

## 13. Governance & Standards
| Capability | Status | Notes / Gaps | Key Artifacts |
|-----------|:------:|--------------|---------------|
| Tagging strategy enforcement | Partial | Tag schema not fully listed | (none) |
| Documentation cross-linking | Implemented | Reciprocal links added | Docs |
| Glossary consistency | Implemented | Maintained | `GLOSSARY.md` |
| Decision records (ADR style) | Deferred | Could add for major tradeoffs | (none) |
| Compliance evidence packaging | Planned | Provide export script | (none) |

## 14. Future / Roadmap Themes
| Theme | Intent | Status |
|-------|--------|:------:|
| AI Ops (predictive scaling, anomaly) | Integrate ML for proactive scaling | Planned |
| Automated tenant migration tooling | Scripted shared→dedicated move | Planned |
| RLS + sample DB schema pack | Provide ready SQL artifacts | Planned |
| Full private networking (no public ingress except edge) | Lock down lateral movement | In Progress |
| Redis + CDN caching strategy | Reduce DB and egress costs | Planned |
| Observability unification (OpenTelemetry) | Distributed tracing standard | Planned |

---
### Summary Assessment
Most core architectural pillars (multi-layer infra, routing, tenancy models, security baseline, observability scaffolding) are Implemented. Gaps center on automation hardening (drift, runbooks), deep data governance (Purview, RLS samples), resilience operations (DR playbooks), and FinOps (cost allocation automation). Identity and tenant lifecycle are solid at the control-plane function level but need migration/deletion automation. Governance guardrails (tag enforcement, policy breadth) remain partially realized.

### Recommended Next 5 Priorities
1. DR & Failover Runbooks (reduce recovery ambiguity)
2. Tagging + Cost Allocation Standard (enable per-CELL chargeback)
3. RLS & Data Schema Sample Pack (accelerate secure adoption)
4. APIM Advanced Policies (tiered throttling, JWT cache, key rotation)
5. Observability Deepening (OpenTelemetry trace pipeline)

---
**📝 Document Version Information**
- **Version**: 1.7.0
- **Last Updated**: 2025-09-08  
- **Status**: Current
- **Next Review**: 2025-11
