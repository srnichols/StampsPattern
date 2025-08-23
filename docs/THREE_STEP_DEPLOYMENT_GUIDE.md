# Three-Step Deployment Process for Management Portal and Routing

This guide outlines the recommended three-step process for deploying the Stamps Pattern infrastructure, global routing, and the Management Portal application. This approach separates infrastructure, routing, and application deployment for maximum reliability and clarity.

---

## Step 1: Deploy Core Infrastructure

1. **Automated Step 1: Deploy and Extract Outputs**
   - Run the `single-sub-deployment-step1.ps1` PowerShell script from the `scripts` folder to deploy `AzureArchitecture/main.bicep` and automatically extract the outputs needed for routing and management portal deployment.
   - This script provisions all resource groups, core assets, and the management portal resource group, then writes the required outputs to `routing.parameters.json` and `management-portal.parameters.json`.
   - Example usage:
      ```pwsh
      pwsh ./scripts/single-sub-deployment-step1.ps1 -SubscriptionId <subscription-id> -Location <primary-location> -Environment <env>
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

For more details, see the project documentation or ask in the project discussions.
