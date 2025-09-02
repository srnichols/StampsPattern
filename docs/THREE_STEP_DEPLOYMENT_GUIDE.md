---

# Three-Step Deployment Process for Management Portal and Routing

This guide outlines the recommended three-step process for deploying the Stamps Pattern infrastructure, global routing, and the Management Portal application. This approach separates infrastructure, routing, and application deployment for maximum reliability and clarity.

---


## Step 1: Deploy Core Infrastructure (Resource Groups and Main Assets)


Run the `single-sub-deployment-step1.ps1` PowerShell script to automate the entire core infrastructure deployment. This script fully automates global identity creation and permissions for all downstream modules. The process includes:

- Deploy the `AzureArchitecture/resourceGroups.bicep` template to create all required resource groups **and** a global user-assigned managed identity in the global resource group.
- Parse and extract the global identity's resource ID and principalId from the deployment outputs.
- Deploy the `AzureArchitecture/globalIdentityRoleAssignment.sub.bicep` template at the subscription scope to assign Contributor to the global identity (no manual role assignment or re-run required).
- Wait 30 seconds to ensure propagation of permissions.
- Deploy the `AzureArchitecture/main.bicep` template using `main.parameters.json`, passing the global identity resource ID to all modules that require it (monitoring, Key Vault, etc.).
- Extract outputs for routing and management portal deployment.
- Write outputs to `routing.parameters.json` and `management-portal.parameters.json` for use in later steps.


**Example usage:**
```pwsh
pwsh ./scripts/single-sub-deployment-step1.ps1 -SubscriptionId <subscription-id> -Location <primary-location> -Environment <env>
```

Optional: Auto-run APIM sync (non-prod only)
- To automatically synchronize APIs/policies from the primary APIM to secondary APIM instances during Step 1 for demo/non-prod environments, pass the `-AutoRunApimSync` switch.
- This runs only when:
   - `Environment` is not `prod`, and
   - multiple APIM gateway URLs are present, and
   - standard Azure endpoints (`*.azure-api.net`) are used.
- It’s intentionally skipped for prod. For custom domains or advanced topologies, run `scripts/apim-sync.ps1` manually with explicit parameters.

Example (auto-sync enabled in non-prod):
```pwsh
pwsh ./scripts/single-sub-deployment-step1.ps1 -SubscriptionId <subscription-id> -Location <primary-location> -Environment test -AutoRunApimSync
```

**Real-world example:**
```pwsh
pwsh ./scripts/single-sub-deployment-step1.ps1 -SubscriptionId "00000000-1111-2222-3333-444455556666" -Location "westus3" -Environment "test" -salt "TeAB"
```


**What the script does:**
- Creates all resource groups as defined in `resourceGroups.bicep`.
- Deploys a global user-assigned managed identity in the global resource group.
- Assigns Contributor at the subscription scope to the global identity (fully automated, no manual step required).
- Waits 30 seconds for propagation.
- Deploys all core assets as defined in `main.bicep`, passing the global identity to all modules that require it.
- Extracts and writes outputs for use in routing and management portal deployment.
- If `-AutoRunApimSync` is provided and conditions are met (non-prod, multiple APIMs, azure-api.net endpoints), runs `scripts/apim-sync.ps1` to sync secondary APIM instances.


**After running the script:**
1. Confirm that all resource groups and assets are created, including the global managed identity, ACR, Key Vault, and `rg-stamps-management-portal-<env>`.
2. The global managed identity will have Contributor at the subscription scope and will be used by all deployment scripts and modules requiring permissions (monitoring, Key Vault, etc.).
3. Review the generated `routing.parameters.json` and `management-portal.parameters.json` files for use in the next steps.

---

## Step 2: Deploy and Validate Global Routing

1. **Automated Step 2: Deploy Routing**
   - Use the `deploy-routing.ps1` script to configure and validate global routing (Front Door, Traffic Manager, DNS, etc.) using the outputs from step 1.
   - Example usage:
      ```pwsh
      pwsh ./scripts/deploy-routing.ps1 -ParametersFile ./routing.parameters.json
      ```
   - The script will:
     - Deploy or update routing resources.
     - Wire up all endpoints and validate DNS.
     - Output public endpoints and routing info for the management portal.

2. **Manual alternative**
   - You can manually deploy routing resources using Azure CLI or Bicep, referencing the outputs in `routing.parameters.json`.

---

## Step 3: Build, Push, and Deploy the Management Portal

1. **Automate build, push, and deployment with deploy-management-portal-container-apps.ps1**
   - Use the `deploy-management-portal-container-apps.ps1` script to automate the process of building the management portal Docker image, pushing it to ACR, and deploying the management portal using the outputs from step 1 and 2.
   - Example usage:
      ```pwsh
      cd AzureArchitecture
      pwsh ../scripts/deploy-management-portal-container-apps.ps1 -ParametersFile ./management-portal.parameters.json
      ```
   - The script will handle all required steps, including setting the `portalImage` parameter and ensuring all required secrets and configuration are provided.
   - Optional: grant discovery across multiple subscriptions with `-AdditionalSubscriptions` (assigns Reader to the portal's managed identity on those subscriptions as well):
      ```pwsh
      cd AzureArchitecture
      pwsh ../scripts/deploy-management-portal-container-apps.ps1 -ParametersFile ./management-portal.parameters.json -AdditionalSubscriptions @('11111111-2222-3333-4444-555555555555','aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee')
      ```
      Note: You (or the executing identity) must have Owner or User Access Administrator on each subscription to create role assignments.

2. **Manual alternative**
   - Build the Docker image locally:
      ```pwsh
      docker build -t <acr-login-server>/portal:<tag> ./management-portal
      ```
   - Log in to ACR:
      ```pwsh
      az acr login --name <acr-name>
      ```
   - Push the image to ACR:
      ```pwsh
      docker push <acr-login-server>/portal:<tag>
      ```
   - Update the management portal Bicep parameters and deploy:
      ```pwsh
      az deployment group create \
         --resource-group rg-stamps-management-portal-<env> \
         --template-file management-portal/infra/management-portal.bicep \
         --parameters portalImage=<acr-login-server>/portal:<tag> ...
      ```

---

## Notes
- Each step produces outputs that are required for the next step. Do not skip steps or modify outputs manually.
- Tags on the resource group are for metadata only; permissions must be set via Azure RBAC or Key Vault access policies.
- Ensure the management portal has access to required secrets and resources.
- Adjust parameter values and secrets as needed for your environment.
- APIM Sync behavior: `-AutoRunApimSync` is safe-by-default. It will not run for `prod` and will only auto-map secondaries using standard Azure endpoints (`*.azure-api.net`). If you plan to use custom domains for APIM, run `./scripts/apim-sync.ps1` manually and provide explicit names.
- SQL cost controls: you can tune SQL Database cost from `AzureArchitecture/main.parameters.json` using `sqlDatabaseSkuTier` and `sqlDatabaseSkuName`. Defaults are environment-aware: S0 for non-prod, S1 for prod. Override as needed.
- APIM cost controls: the templates use Developer tier for non-prod and Premium for prod. For a low-cost multi-region demo, multiple Developer instances are fronted by Front Door; `-AutoRunApimSync` can sync APIs/policies between regions in non-prod.

---
## Special Parameters for Repeated Deployments

**salt**: To avoid Azure soft-delete conflicts (e.g., with Key Vaults), a `salt` parameter is now supported. This can be any short string (date, initials, random chars) and will be appended to resource names like Key Vault. Update the `salt` value in your deployment parameters or script for each new deployment attempt on the same day.

**How to use:**
- Add or update the `salt` parameter in your deployment command or parameters file (e.g., `-salt 20250824a`).
- This ensures unique resource names and prevents soft-delete name collisions.

**Example:**
```pwsh
pwsh ./scripts/single-sub-deployment-step1.ps1 -SubscriptionId <subscription-id> -Location <primary-location> -Environment <env> -Salt 20250824a
```

If you encounter a Key Vault name conflict, simply change the `salt` value and redeploy.
---

## Feature Toggle Reference: Enable Flags in Bicep Templates

The following table lists all `enable*` flags (feature toggles) available in the main and downstream Bicep templates. Use these flags to control optional features and deployment behaviors.

| Flag Name                        | Description                                                        | Template File                                 |
|----------------------------------|--------------------------------------------------------------------|-----------------------------------------------|
| enableGlobalFunctions            | Enable deployment of global Function Apps and their plans/storage (disable in smoke/lab to avoid quota) | main.bicep, globalLayer.bicep, hub-main.bicep |
| enableStorageObjectReplication   | Enable Blob Object Replication (ORS) from each CELL to a destination account | main.bicep, deploymentStampLayer.bicep        |
| enableSqlFailoverGroup           | Enable SQL Auto-failover Group for each CELL                       | main.bicep, deploymentStampLayer.bicep        |
| enableGlobalCosmos               | Enable deployment of global Cosmos DB resources                     | globalLayer.bicep, hub-main.bicep             |
| enableFrontDoorDiagnostics       | Enable diagnostics for Azure Front Door                             | globalLayer.bicep                             |
| enableTrafficManagerDiagnostics  | Enable diagnostics for Azure Traffic Manager                        | globalLayer.bicep                             |
| enableContainerRegistry          | Enable Azure Container Registry for this CELL (disabled in smoke)   | deploymentStampLayer.bicep                    |
| enableContainerAppEnvironment     | Enable deployment of Container App Environment for this CELL         | deploymentStampLayer.bicep                    |
| enablePrivateEndpoints           | Enable private endpoints for enhanced security                      | deploymentStampLayer.bicep                    |
| enableApplicationGateway         | Enable Application Gateway WAF for advanced threat protection       | deploymentStampLayer.bicep                    |
| enableCellTrafficManager         | Enable a per-cell Traffic Manager profile (disabled in smoke)       | deploymentStampLayer.bicep                    |
| enableAdvancedThreatProtection   | Enable advanced threat protection features                          | advancedSecurity.bicep, advancedSecurityResourceGroup.bicep |
| enableAzureDefender              | Enable Azure Defender for all supported resource types              | advancedSecurity.bicep                        |
| enableHttps                      | Enable HTTPS for Application Gateway                                | regionalLayer.bicep                           |
| enableAutomation                 | Enable Automation Account deployment                                | regionalLayer.bicep                           |
| cosmosZoneRedundant              | Enable zone redundancy for Cosmos DB (true = zone redundant, false = non-zonal). Defaults: true in prod, false otherwise. | globalLayer.bicep                            |

> **Tip:** Set these flags in your parameters files (e.g., `main.parameters.json`) to control deployment features as needed.

For more details, see the project documentation or ask in the project discussions.

---

## Troubleshooting: Cosmos DB Zone Redundancy and Storage Diagnostics

### Cosmos DB AZ Migration Capability Error

If you see an error like:

```
"code": "BadRequest",
"message": "AZ migration capability is disabled for subscription ..."
```

This means your subscription does not have the Account Zone Redundancy (AZ) migration feature enabled for Cosmos DB. Unless you have specifically requested this feature from Microsoft, you must set the `cosmosZoneRedundant` flag to `false` in your parameters file. Attempting to enable zone redundancy without this capability will cause deployment failures.

**Action:**
- Set `cosmosZoneRedundant` to `false` in your parameters (e.g., `main.parameters.json`).
- If you require zone redundancy, open a support request with Microsoft to enable this feature for your subscription.

### Storage Diagnostics Category Error

If you see an error like:

```
"code": "BadRequest",
"message": "Category 'StorageRead' is not supported."
```

This means the diagnostic category you are trying to enable (e.g., `StorageRead`) is not supported for the target Storage Account or in your region/subscription.

**Action:**
- Review your Bicep/ARM template for diagnostic settings on Storage Accounts.
- Only use supported diagnostic categories. Remove or correct any unsupported categories.

For a list of supported diagnostic categories, see the [Azure documentation](https://learn.microsoft.com/azure/azure-monitor/reference/supported-diagnostic-logs).

---

---

## Log Analytics Workspace (LAW) and Diagnostics Reference

### What is the `customerId` and why does it matter?

The `customerId` is a globally unique identifier (GUID) for a Log Analytics Workspace (LAW) in Azure Monitor. It is required by downstream resources (such as Container App Environments, diagnostics, and monitoring agents) to connect and send telemetry to the correct workspace. In Bicep deployments, the `customerId` is typically output by the module that provisions the LAW (e.g., `monitoringLayer.bicep`) and must be passed as a parameter to any module or resource that needs to send logs or metrics to that workspace.

**Key points:**
- The `customerId` is NOT the resourceId; it is a GUID property of the LAW resource.
- Some Azure resources (e.g., Container App Environment) require the `customerId` at deployment time to configure diagnostics.
- The `customerId` is only available after the LAW is fully provisioned, so Bicep modules must use explicit `dependsOn` to ensure correct sequencing.
- If the `customerId` is not available or is invalid at deployment time, dependent resources will fail to deploy with errors like `LogAnalyticsConfiguration is invalid`.

### Reference Table: LAW/Diagnostics Parameters and Outputs

| Name/Parameter                | Description                                                                 | Source/Usage                        |
|-------------------------------|-----------------------------------------------------------------------------|-------------------------------------|
| `logAnalyticsWorkspaceId`     | Resource ID of the LAW (used for RBAC, diagnostic settings, etc.)           | Output from `monitoringLayer.bicep` |
| `logAnalyticsCustomerId`      | GUID of the LAW (required for Container App Env, agents, etc.)              | Output from `monitoringLayer.bicep` |
| `globalLogAnalyticsWorkspaceId` | Resource ID for global diagnostics (passed to globalLayer, etc.)            | Parameter in `main.bicep`           |
| `logAnalyticsCustomerId` (parameter) | Passed to modules that need to configure diagnostics (e.g., deploymentStampLayer) | Parameter in `main.bicep`, `deploymentStampLayer.bicep` |
| `diagnosticSettings`          | Diagnostic settings block referencing LAW                                   | Used in various modules             |

**Propagation Example:**
- `main.bicep` deploys `monitoringLayer.bicep` → outputs `logAnalyticsWorkspaceId` and `logAnalyticsCustomerId`.
- `main.bicep` passes these outputs as parameters to `globalLayer.bicep` and each `deploymentStampLayer.bicep`.
- Each downstream module uses the `customerId` to configure diagnostics for resources (e.g., Container App Environment, App Service, Key Vault, etc.).

> **Tip for new developers:**
> Always ensure that any resource or module requiring diagnostics or monitoring is passed the correct `customerId` and that module dependencies are set so the LAW is fully provisioned before its value is needed.

For more details, see the in-code comments in `main.bicep`, `monitoringLayer.bicep`, and `deploymentStampLayer.bicep`, or ask in project discussions.
