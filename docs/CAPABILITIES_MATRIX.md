# Capabilities Matrix

This matrix summarizes implemented, in-progress, and planned features across the Azure Stamps Pattern. Use it to see which areas are production-ready and which are experimental.

| Capability | Status | Notes |
|-----------:|:------:|:-----|
| Core infra (Bicep) | Implemented | Global/hub/regional layers and sample deployments. |
| Management Portal | Implemented | Blazor UI with DAB GraphQL; currently migrating from mock data to DAB-backed live data. |
| DAB (Data API Builder) | Deployed | Custom image and schema present; monitor container app health and ensure IaC aligns targetPort and image config. |
| Seeder (Cosmos) | Implemented | Seeder with AAD auth; required RBAC adjustments to seed data. |
| CI (image build & push) | Implemented (basic) | GitHub Actions with image build; recommend OIDC federation for minimal secrets. |
| Key Vault integration | Implemented | Secrets used; recommend migration from container-app secrets to KV references for production. |
| Advanced monitoring | Implemented | Monitoring dashboards and App Insights wiring present. |
| Policy as code | Implemented | Policy modules included in Bicep templates.
| WAF & Security baseline | Implemented | CAF/WAF best-practices incorporated.
| Autoscale & performance tuning | Available | Autoscale examples included; consider RU autoscale for Cosmos in production.

Legend

- Implemented — shipped and tested in sample deployments
- In-progress — available but needs stabilization or additional testing
- Planned — roadmap item
---

**📝 Document Version Information**
- **Version**: 1.6.3
- **Last Updated**: 2025-09-03 13:38:15 UTC  
- **Status**: Current
- **Next Review**: 2025-11
