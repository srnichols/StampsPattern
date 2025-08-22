# Two-Step Deployment Process for Management Portal

This guide outlines the recommended two-step process for deploying the Stamps Pattern infrastructure and the Management Portal application.

---

## Step 1: Deploy Core Infrastructure

1. **Automated Step 1: Deploy and Extract Outputs**
    - Run the `single-sub-deployment-step1.ps1` PowerShell script located in the `AzureArchitecture` folder to deploy `AzureArchitecture/main.bicep` and automatically extract the outputs needed for the management portal deployment.
    - This script provisions all resource groups, core assets, and the management portal resource group, then writes the required outputs to `management-portal.parameters.json`.
    - Example usage:
       ```pwsh
       cd AzureArchitecture
       pwsh ./single-sub-deployment-step1.ps1
       ```

   - The script will:
     - Deploy the Bicep template using `main.parameters.json`.
     - Extract the `managementPortalDeploymentParams` output.
     - Write the output to `management-portal.parameters.json` for use in step 2.

2. **Wait for deployment to complete**
   - Confirm that all resource groups and assets are created, including the ACR, Key Vault, and `rg-stamps-management-portal-<env>`.

3. **Review generated outputs**
   - The script will generate `management-portal.parameters.json` containing all parameters needed for the management portal deployment.
   - You can also review other outputs as needed for image push and configuration.

---

## Step 2: Build, Push, and Deploy the Management Portal


1. **Automate build, push, and deployment with deploy-management-portal-container-apps.ps1**
   - Use the `deploy-management-portal-container-apps.ps1` script to automate the process of building the management portal Docker image, pushing it to ACR, and deploying the management portal using the outputs from step 1.
    - The script will:
       - Build the Docker image for the management portal.
       - Log in to Azure Container Registry (ACR).
       - Push the image to ACR.
       - Deploy the management portal Bicep template to the management portal resource group, using the generated `management-portal.parameters.json` file.
   - Example usage:
      ```pwsh
      cd AzureArchitecture
      pwsh ../scripts/deploy-management-portal-container-apps.ps1 -ParametersFile ./management-portal.parameters.json
      ```

    - The script will handle all required steps, including setting the `portalImage` parameter and ensuring all required secrets and configuration are provided.

2. **Manual alternative (if not using the script)**
    - You can still perform the steps manually as described below:
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
- Tags on the resource group are for metadata only; permissions must be set via Azure RBAC or Key Vault access policies.
- Ensure the management portal has access to required secrets and resources.
- Adjust parameter values and secrets as needed for your environment.

---

For more details, see the project documentation or ask in the project discussions.
