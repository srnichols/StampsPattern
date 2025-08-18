# Setup GitHub Secrets for Azure Deployment

The GitHub Actions workflow needs Azure authentication to deploy. Follow these steps:

## Step 1: Create Azure Service Principal

Run this command in your terminal (you'll need Azure CLI working):

```powershell
# Create a service principal with Contributor role
az ad sp create-for-rbac --name "github-actions-stamps" --role contributor --scopes /subscriptions/YOUR_SUBSCRIPTION_ID --sdk-auth

# Replace YOUR_SUBSCRIPTION_ID with your actual subscription ID
```

This will output JSON like:
```json
{
  "clientId": "xxx-xxx-xxx",
  "clientSecret": "xxx-xxx-xxx", 
  "subscriptionId": "xxx-xxx-xxx",
  "tenantId": "xxx-xxx-xxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

## Step 2: Add GitHub Repository Secrets

1. Go to: https://github.com/srnichols/StampsPattern/settings/secrets/actions

2. Click **"New repository secret"** and add these:

   **Secret Name:** `AZURE_CREDENTIALS`  
   **Value:** Paste the ENTIRE JSON output from Step 1

   **Secret Name:** `AZURE_SUBSCRIPTION_ID`  
   **Value:** Your subscription ID (just the GUID)

## Step 3: Verify Secrets

The workflow should now have access to:
- `secrets.AZURE_CREDENTIALS` - Full service principal JSON
- `secrets.AZURE_SUBSCRIPTION_ID` - Your subscription ID

## Step 4: Re-run the Workflow

After adding the secrets:
1. Go to GitHub Actions
2. Find the failed workflow run
3. Click **"Re-run jobs"** → **"Re-run all jobs"**

## Alternative: Use OIDC Authentication (Modern Method)

If you prefer the newer OIDC method, we can update the workflow to use:
- `client-id`
- `tenant-id` 
- `subscription-id`

Let me know which approach you prefer!
