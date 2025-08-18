# Production SaaS Checklist, One‑Pager

A concise, printable pre‑go‑live checklist for promoting the Azure Stamps Pattern from test to production.

Last updated: August 8, 2025

---

## Organization & Domains

- [ ] Global tenant domain reservation enforced (no duplicates across tenants)
- [ ] API rejects duplicate domains; reservation cleaned up on tenant delete
- [ ] Parameterization (org name, DNS base, GEO) reviewed and applied

## Identity & Access

- [ ] Built‑in auth enabled on Container Apps and Functions (no anonymous)
- [ ] Entra ID groups mapped to app roles (e.g., platform.admin)
- [ ] DAB roles aligned to least privilege for non‑admins
- [ ] CORS restricted to approved origins only

## API Surface & DAB

- [ ] Disable unneeded mutations; restrict filters/projections
- [ ] Disable dev features in prod (verbose errors; GraphQL introspection if policy requires)
- [ ] Rate limiting/WAF policies at public entry points (APIM/App Gateway)

## Data (Cosmos DB)

- [ ] Partition keys validated (tenants: /tenantId; operations TTL; catalogs: /type)
- [ ] RU auto‑scale or throughput configured; composite indexes match read paths
- [ ] PITR/backups configured; failover priorities set; consistency level confirmed
- [ ] Access via managed identity only; secrets in Key Vault

## Networking (Zero‑Trust)

- [ ] Private endpoints for data planes; ACA VNET integration enabled
- [ ] Ingress locked; egress scoped; NSG/WAF/DDOS baselines applied
- [ ] No unintended public exposure for data services

## Observability

- [ ] App Insights + Log Analytics wired; dashboards for availability/latency/errors
- [ ] Alerts: auth failures, Cosmos 429, RU budgets, container restarts
- [ ] Log retention and sampling policies set

## Resilience & DR

- [ ] Region pairs and failover/runbooks validated
- [ ] Periodic restore tests from backups completed
- [ ] Capacity tests and scale rules reviewed

## Cost & Governance

- [ ] Budgets and anomaly alerts configured
- [ ] Image/artifact and log retention policies enforced
- [ ] Azure Policy assigned; Defender for Cloud recommendations addressed

---

References

- Deployment Guide, Production SaaS Checklist (docs/DEPLOYMENT_GUIDE.md)
- Management Portal Plan, Domain reservation and data model (docs/MANAGEMENT_PORTAL_PLAN.md)
- Security Baseline, Identity, network, and zero‑trust (docs/SECURITY_GUIDE.md)
- Parameterization Guide, Org/geography/DNS inputs (docs/PARAMETERIZATION_GUIDE.md)

---

Prepared by: ____________________________   Date: __________

Approved by: ____________________________   Date: __________
