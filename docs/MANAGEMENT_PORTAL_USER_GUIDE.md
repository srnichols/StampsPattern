# Management Portal - User Guide

This guide explains how to onboard, manage, and operate tenants/customers using the Management Portal (Control Plane UI).

---

## Audience
- Platform administrators
- Operators/SREs
- Support engineers

## Prerequisites
- Entra ID account with one of the following roles:
  - Platform.Admin (full admin)
  - Operator (manage routing and operations)
  - Reader (read-only)
- Network access to the portal URL

---

## Concepts
- Tenant: A customer instance with metadata, placement, and routing rules
- Cell: A deployment unit hosting one or more tenants
- Operation: A workflow (e.g., migration) tracked as steps with status

---

## Onboarding a New Tenant
1. Open the portal and navigate to Tenants → New Tenant
2. Provide:
   - Tenant ID (immutable) and Display Name
   - Organization Domain (e.g., contoso.com)
   - Tier (startup/smb/enterprise)
   - Compliance Flags (HIPAA, PCI, GDPR)
   - Initial Placement (Cell, Geo/Region, AZ)
   - Base Domain and APIM Product (if applicable)
3. Save to create the tenant record
4. Monitor initial status; the system emits a TenantCreated event (infra automation optional)

### Validations
- Tenant ID must be unique
- Placement must reference an existing Cell
- Compliance + region pinning rules enforced

---

## Updating Routing Rules
1. Open Tenants → Select Tenant → Routing tab
2. Update strategy (geo, performance, compliance) and base domain
3. (Optional) Set traffic weights when multi-homing
4. Save; a RouteUpdated event is emitted

---

## Migrating a Tenant
1. Open Tenants → Select Tenant → Actions → Migrate Tenant
2. Choose destination Cell and confirm compliance
3. The portal creates a Migration Operation with steps:
   - provisionTarget → syncData → drainAndCutover → validate
4. Track progress under Operations; approve/rollback as needed

---

## Suspending/Resuming a Tenant
- From Tenant page: Actions → Suspend (or Resume)
- Status updates reflect immediately; traffic may be shed/blocked per policy

---

## Decommissioning a Tenant
- From Tenant page: Actions → Decommission → Confirm
- Data export/retention executed per policy; status moves to decommissioned

---

## Managing Cells
- Navigate to Cells:
  - Review health, capacity, and utilization snapshots
  - Mark Cell as constrained to prevent new placements

---

## Audit & Reporting
- Operations log lists who changed what, when
- Export audit trail for compliance reviews

---

## Troubleshooting
- If changes don’t appear immediately, refresh (Cosmos eventual consistency)
- Check App Insights for errors (portal/backend)
- For migration failures: review Operation details → retry failed step or rollback

---

## FAQ
- Q: Can I change the Tenant ID?  
  A: No. Tenant ID is immutable; use Display Name for changes.
- Q: Can I move tenants across geos with compliance flags?  
  A: Not unless the policy allows; the portal will block or require an exception.

---

## Links
- Platform Overview: ./DOCS.md
- Contribution Guidelines: ../CONTRIBUTING.md
