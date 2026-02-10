# Multi-Environment — Instructions

applyTo: "AzureArchitecture/main.bicep,AzureArchitecture/**/*.parameters.json,AzureArchitecture/deploymentStampLayer.bicep,AzureArchitecture/geodesLayer.bicep"

## Environment Strategy

All environments deploy from the **same Bicep templates** — differences are controlled entirely via parameters.

### Environment Tiers

| Environment | Purpose | Cost Profile |
|-------------|---------|--------------|
| `dev` | Developer iteration, experimentation | Minimal — Developer APIM, Free Defender, S0 SQL |
| `test` | Integration testing (default) | Same as dev |
| `staging` | Pre-production validation, load testing | Near-prod |
| `prod` | Live production workloads | Full — Premium APIM, paid Defender, zone-redundant Cosmos |

### Environment-Aware Parameter Patterns

Use ternary expressions in Bicep for environment-driven defaults:

```bicep
@allowed(['dev', 'test', 'staging', 'prod'])
param environment string = 'test'

// SKU tiers
var apimSkuName = environment == 'prod' ? 'Premium' : 'Developer'
param sqlDatabaseSkuName string = (environment == 'prod' ? 'S1' : 'S0')
param sqlDatabaseSkuTier string = (environment == 'prod' ? 'Standard' : 'Standard')

// Security features
param cosmosZoneRedundant bool = (environment == 'prod')
param enableDefenderForStorage bool = (environment == 'prod')
param enableDefenderForSql bool = (environment == 'prod')
param defenderForServersPlan string = (environment == 'prod' ? 'P1' : 'Off')

// Feature toggles
param enableGlobalFunctions bool = true   // false for smoke/lab
param enableContainerRegistry bool = false // true when deploying containers
param enablePrivateEndpoints bool = false  // true in prod
param enableApplicationGateway bool = false // true in prod
```

### Resource Naming by Environment

All resource names include the environment suffix:

```
rg-stamps-global-{environment}
rg-stamps-cell-{cellName}-{environment}
stamps-zero-trust-nsg-{environment}
stamps-pattern-alerts-{environment}
```

### Parameter Files

| File | Target |
|------|--------|
| `main.parameters.json` | Default/test deployment |
| `hub-main.parameters.json` | Hub-and-spoke network model |
| `hub-main.frontdoor.parameters.json` | Front Door configuration |
| `hub-main.global.parameters.json` | Global layer parameters |
| `routing.parameters.json` | Traffic routing configuration |
| `resourceGroups.parameters.json` | Resource group definitions |

### Cost Optimization by Environment

#### Non-Production (dev/test)

- APIM: Developer SKU (single instance, no SLA)
- SQL: S0 tier
- Defender: All plans at Free/Off
- Cosmos: No zone redundancy
- Container Registry: Disabled
- Private endpoints: Disabled
- Application Gateway: Disabled

#### Production

- APIM: Premium SKU (multi-region, 99.95% SLA)
- SQL: S1+ tier
- Defender: P1 servers, paid storage/SQL
- Cosmos: Zone-redundant, multi-region replication
- Container Registry: Enabled
- Private endpoints: Enabled
- Application Gateway: Enabled with WAF

### Smoke/Lab Deployments

For quick validation without full resource provisioning:

```bicep
param enableGlobalFunctions bool = false    // Skip function apps (quota-friendly)
param enableContainerAppEnvironment bool = false // Skip container infra
param enableCellTrafficManager bool = false     // Skip per-cell TM profiles
```

Use `examples/main.sample.smoke.json` for smoke-test parameter sets.

### Environment Detection in Application Code

```csharp
// Blazor Portal
if (builder.Environment.IsProduction())
{
    // Enable authentication, HTTPS enforcement, forwarded headers
}
else
{
    // Relaxed auth, development features
}
```

### CI/CD Environment Promotion

Deployment order: `dev` → `test` → `staging` → `prod`

- Same Bicep templates at every stage
- Only parameter files change
- What-if preview required before prod deployment
- Manual approval gate for production
