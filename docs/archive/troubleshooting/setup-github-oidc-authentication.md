# Setup OIDC Authentication for GitHub Actions

## Overview

OIDC (OpenID Connect) authentication often bypasses Conditional Access policies that block service principal credentials. We'll switch from using `AZURE_CREDENTIALS` to individual OIDC secrets.

## Part 1: Configure Federated Credential in Azure

### Step 1: Add Federated Credential to App Registration

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** > **App registrations**
3. Find and click on **github-actions-stamps**
   - Application ID: `e691193e-4e25-4a72-9185-1ce411aa2fd8`
4. In the left menu, click **Certificates & secrets**
5. Click on the **Federated credentials** tab
6. Click **Add credential**

### Step 2: Configure GitHub Actions Credential

In the "Add a credential" form:

- **Federated credential scenario**: Select **"GitHub Actions deploying Azure resources"**
- **Organization**: `srnichols`
- **Repository**: `StampsPattern`
- **Entity type**: Select **"Branch"**
- **GitHub branch name**: `master`
- **Name**: `github-actions-stamps-oidc-master`
- **Description**: `OIDC credential for GitHub Actions deployment from master branch`

Click **Add** to create the federated credential.

## Part 2: Update GitHub Repository Secrets

### Step 1: Remove Old Secret

1. Go to <https://github.com/srnichols/StampsPattern>
2. Click **Settings** tab
3. In left sidebar, click **Secrets and variables** > **Actions**
4. Find and **Delete** the `AZURE_CREDENTIALS` secret

### Step 2: Add New OIDC Secrets

Add these three new secrets:

**Secret Name: `AZURE_CLIENT_ID`**

```
e691193e-4e25-4a72-9185-1ce411aa2fd8
```

**Secret Name: `AZURE_TENANT_ID`**

```
16b3c013-d300-468d-ac64-7eda0820b6d3
```

**Secret Name: `AZURE_SUBSCRIPTION_ID`**  

```
480cb033-9a92-4912-9d30-c6b7bf795a87
```

## Part 3: Test the Configuration

After completing both parts above:

1. Push a test commit to trigger GitHub Actions
2. Monitor the workflow logs for successful authentication
3. Verify no "Conditional Access" errors appear

## Expected Results

✅ **Success indicators:**

- Azure login step shows: "Successfully logged in with OIDC"
- No "AADSTS53003" Conditional Access errors
- Azure CLI commands execute successfully
- Container Apps deployment proceeds normally

❌ **If still failing:**

- Check federated credential configuration
- Verify GitHub secrets are set correctly
- Ensure service principal still has Contributor role on subscription

## Benefits of OIDC

- **More secure**: No long-lived secrets stored in GitHub
- **Bypasses Conditional Access**: Often exempted from location-based policies  
- **Azure recommended**: Microsoft's preferred authentication method for CI/CD
- **Automatic rotation**: No manual secret renewal needed

## Troubleshooting

If you encounter issues:

1. Verify federated credential shows "Active" status in Azure Portal
2. Check that branch name exactly matches: `master`
3. Ensure organization/repository names are correct: `srnichols/StampsPattern`
4. Confirm service principal still has Contributor role on subscription
