# Updated GitHub Secrets Setup (OIDC Method - Recommended)

The modern way to authenticate GitHub Actions with Azure uses OpenID Connect (OIDC). This is more secure and easier to set up.

## Step 1: Create Azure App Registration

Since Azure CLI isn't working on your machine, you can do this in the Azure Portal:

1. Go to **Azure Portal** → **Microsoft Entra ID** → **App registrations**
2. Click **"New registration"**
3. Name: `github-actions-stamps-pattern`
4. Click **"Register"**

## Step 2: Note Down IDs

After creating the app registration, note these values:

- **Application (client) ID**: Found on the Overview page
- **Directory (tenant) ID**: Found on the Overview page  
- **Subscription ID**: Your Azure subscription ID (you already know this)

## Step 3: Configure Federated Credentials

1. In your app registration, go to **"Certificates & secrets"**
2. Click **"Federated credentials"** tab
3. Click **"Add credential"**
4. Select **"GitHub Actions deploying Azure resources"**
5. Fill in:
   - **Organization**: `srnichols`
   - **Repository**: `StampsPattern`
   - **Entity type**: `Branch`
   - **GitHub branch name**: `master`
   - **Name**: `github-actions-deploy`
6. Click **"Add"**

## Step 4: Assign Azure Permissions

1. Go to **Azure Portal** → **Subscriptions** → **Your Subscription**
2. Click **"Access control (IAM)"**
3. Click **"Add"** → **"Add role assignment"**
4. Select **"Contributor"** role
5. Click **"Next"**
6. Select **"User, group, or service principal"**
7. Search for `github-actions-stamps-pattern` (your app registration)
8. Select it and click **"Review + assign"**

## Step 5: Add GitHub Secrets

Go to: <https://github.com/srnichols/StampsPattern/settings/secrets/actions>

Add these three secrets:

**Secret Name:** `AZURE_CLIENT_ID`  
**Value:** The Application (client) ID from Step 2

**Secret Name:** `AZURE_TENANT_ID`  
**Value:** The Directory (tenant) ID from Step 2

**Secret Name:** `AZURE_SUBSCRIPTION_ID`  
**Value:** Your subscription ID

## Step 6: Update Workflow

I'll update the workflow to use OIDC authentication instead of the old service principal method.

This is much more secure because:

- ✅ No client secrets stored in GitHub
- ✅ Temporary tokens only
- ✅ Scoped to your specific repository and branch
- ✅ Modern Azure authentication method
---

**📝 Document Version Information**
- **Version**: 1.3.0
- **Last Updated**: 2025-08-18 01:28:00 UTC  
- **Status**: Current
- **Next Review**: 2025-11