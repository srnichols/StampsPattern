# Add GitHub Secrets - Step by Step Guide

Since I can't add secrets directly, here's exactly what you need to do:

## Step 1: Get Your Tenant ID

1. Go to Azure Portal and find your container app `ca-stamps-portal`
2. Note the **Directory (tenant) ID** shown in the portal
3. This should be the tenant where you can see your container apps

## Step 2: Create Service Principal

1. **Azure Portal** → **Microsoft Entra ID** → **App registrations** 
2. Make sure you're in the correct tenant (same as where your container apps are)
3. Click **"New registration"**
4. Name: `github-actions-stamps-sp`
5. Click **"Register"**
6. **Copy the Application (client) ID**
7. **Copy the Directory (tenant) ID**

## Step 3: Create Client Secret

1. In your app registration → **"Certificates & secrets"**
2. Click **"New client secret"**
3. Description: `GitHub Actions`
4. Expiration: `24 months`
5. Click **"Add"**
6. **⚠️ COPY THE SECRET VALUE IMMEDIATELY** (it won't show again)

## Step 4: Assign Permissions

1. **Subscriptions** → **MCAPS-Hybrid-REQ-103709-2024-scnichol-Hub**
2. **Access control (IAM)** → **Add role assignment**
3. Role: **Contributor**
4. Select: `github-actions-stamps-sp`
5. Click **Review + assign**

## Step 5: Create JSON for AZURE_CREDENTIALS

Replace YOUR_* placeholders with actual values:

```json
{
  "clientId": "YOUR_CLIENT_ID_FROM_STEP_2",
  "clientSecret": "YOUR_CLIENT_SECRET_FROM_STEP_3",
  "subscriptionId": "480cb033-9a92-4912-9d30-c6b7bf795a87",
  "tenantId": "YOUR_TENANT_ID_FROM_STEP_2",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

## Step 6: Add to GitHub

**CLICK THIS LINK:** https://github.com/srnichols/StampsPattern/settings/secrets/actions

Then add these secrets:

**Secret 1:**
- Name: `AZURE_CREDENTIALS`
- Value: The entire JSON from Step 5

**Secret 2:** 
- Name: `AZURE_SUBSCRIPTION_ID`
- Value: `480cb033-9a92-4912-9d30-c6b7bf795a87`

## Step 7: Test

After adding secrets, go to:
https://github.com/srnichols/StampsPattern/actions

Find the failed workflow runs and click **"Re-run jobs"**

## Verification

The simple workflow should then:
✅ Authenticate successfully
✅ Build the .NET app
✅ List your container apps
✅ Show success message

Let me know when you've added the secrets and I'll help you test!
