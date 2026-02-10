# Azure — Instructions

applyTo: "AzureArchitecture/**/*.bicep,scripts/**/*.ps1,.github/workflows/**/*.yml"

## Azure Services Used

This solution uses the following Azure services. Always follow Azure best practices when working with any of them.

### Global Tier

| Service | Purpose | Bicep Module |
|---------|---------|--------------|
| Azure Front Door | Global load balancing, WAF, SSL termination | `globalLayer.bicep` |
| Traffic Manager | DNS-based routing (secondary) | `globalLayer.bicep` |
| Azure DNS | Custom domain management | `globalLayer.bicep` |
| Azure Functions | Global tenant management APIs | `globalLayer.bicep` |
| Cosmos DB | Global control plane (tenant routing, CELL metadata) | `geodesLayer.bicep` |
| API Management | Gateway, rate limiting, JWT validation, developer portal | `geodesLayer.bicep` |

### Per-Region Tier

| Service | Purpose | Bicep Module |
|---------|---------|--------------|
| Virtual Network | Network isolation, subnets | `regionalNetwork.bicep` |
| Log Analytics | Centralized logging and monitoring | `monitoringLayer.bicep` |
| Application Insights | APM, distributed tracing | `monitoringLayer.bicep` |

### Per-CELL (Stamp) Tier

| Service | Purpose | Bicep Module |
|---------|---------|--------------|
| Azure SQL | Per-CELL data store | `deploymentStampLayer.bicep` |
| Azure Storage | Blob/Table/Queue per-CELL | `deploymentStampLayer.bicep` |
| Azure Key Vault | Secrets, certificates per-CELL | `deploymentStampLayer.bicep` |
| Container Apps | Application hosting | `deploymentStampLayer.bicep` |
| Container Registry | Container image storage | `deploymentStampLayer.bicep` |
| Application Gateway | WAF v2, per-CELL routing | `deploymentStampLayer.bicep` |
| Redis Cache | Tenant routing cache | configured in app code |

### Security & Governance

| Service | Purpose | Bicep Module |
|---------|---------|--------------|
| Microsoft Defender | Threat detection | `defenderPlans.bicep` |
| Azure Policy | Compliance enforcement | `policyAsCode.bicep` |
| Managed Identity | Passwordless auth | `managedIdentity.bicep`, `globalIdentity.bicep` |
| Network Security Groups | Micro-segmentation | `zeroTrustSecurity.bicep` |

### Identity

| Service | Purpose |
|---------|---------|
| Microsoft Entra External ID | Customer-facing identity (tenants) |
| Microsoft Entra ID | Internal operator identity (portal) |

## Azure CLI Usage

- Use `az` CLI for all Azure operations in scripts (portable across OS)
- Authenticate via `az login` locally, service principal in CI
- Always specify `--subscription` to avoid ambiguity
- Use `az deployment sub create` for subscription-scoped deployments
- Use `az deployment group create` for resource-group-scoped deployments
- Preview changes with `az deployment sub what-if` before applying

## Resource Deployment Order

1. Resource groups (subscription scope)
2. Monitoring layer (Log Analytics, App Insights)
3. Global layer (DNS, Traffic Manager, Front Door, Functions, Cosmos DB)
4. Geodes layer (APIM, Cosmos replication)
5. Regional layer (networking)
6. Deployment stamp layer (per-CELL resources)
7. Security layer (NSGs, policies, Defender)
8. Routing configuration (Front Door rules, Traffic Manager endpoints)

@azure Rule - Use Azure Best Practices: When generating code for Azure, running terminal commands for Azure, or performing operations related to Azure, invoke your `azure_development-get_best_practices` tool if available.
