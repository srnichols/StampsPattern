---

# Three-Step Deployment Process for Management Portal and Routing

This guide outlines the recommended three-step process for deploying the Stamps Pattern infrastructure, global routing, and the Management Portal application. This approach separates infrastructure, routing, and application deployment for maximum reliability and clarity.

---

## Step 1: Deploy Core Infrastructure


### Step 1a: Create Resource Groups
   - Deploy the `resourceGroups.bicep` template to create all required resource groups before deploying any assets.
   - Example usage:
      ```pwsh
      az deployment sub create \
        --location <primary-location> \
        --template-file ./AzureArchitecture/resourceGroups.bicep \
        --parameters @./AzureArchitecture/resourceGroups.parameters.json \
        --subscription <subscription-id>
      ```
   - This ensures all resource groups exist and are named correctly before proceeding.

### Step 1b: Deploy Core Assets and Extract Outputs
   - After all resource groups are created, run the `single-sub-deployment-step1.ps1` PowerShell script to deploy `AzureArchitecture/main.bicep` and extract outputs needed for routing and management portal deployment.
   - Example usage:
      ```pwsh
      pwsh ./scripts/single-sub-deployment-step1.ps1 -SubscriptionId <subscription-id> -Location <primary-location> -Environment <env>
      ```
   - Concrete example (replace values as needed):
      ```pwsh
      pwsh ./scripts/single-sub-deployment-step1.ps1 -SubscriptionId 00000000-1111-2222-3333-444455556666 -Location westus3 -Environment test -salt jChBrq
      ```
   - The script will:
     - Deploy the Bicep template using `main.parameters.json`.
     - Extract outputs for routing and management portal deployment.
     - Write outputs to `routing.parameters.json` and `management-portal.parameters.json` for use in later steps.

2. **Wait for deployment to complete**
   - Confirm that all resource groups and assets are created, including ACR, Key Vault, and `rg-stamps-management-portal-<env>`.

3. **Review generated outputs**
   - The script will generate `routing.parameters.json` and `management-portal.parameters.json` containing all parameters needed for the next steps.

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
| cosmosZoneRedundant              | Enable zone redundancy for Cosmos DB (true = zone redundant, false = non-zonal) | geodesLayer.bicep                            |

> **Tip:** Set these flags in your parameters files (e.g., `main.parameters.json`) to control deployment features as needed.

For more details, see the project documentation or ask in the project discussions.
