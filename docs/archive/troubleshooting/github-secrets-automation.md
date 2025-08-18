# GitHub Secrets Setup Script

## Copy and Paste These Commands

After you set up the federated credential in Azure Portal, use these commands to quickly set up your GitHub secrets.

### Prerequisites

1. Install GitHub CLI: `winget install GitHub.cli` or download from <https://cli.github.com/>
2. Authenticate: `gh auth login`

### Quick Setup Commands

```powershell
# Navigate to your repository (if not already there)
cd E:\GitHub\StampsPattern

# Authenticate with GitHub CLI (if not already done)
gh auth login

# Set up the three OIDC secrets
gh secret set AZURE_CLIENT_ID --body "e691193e-4e25-4a72-9185-1ce411aa2fd8"
gh secret set AZURE_TENANT_ID --body "16b3c013-d300-468d-ac64-7eda0820b6d3"
gh secret set AZURE_SUBSCRIPTION_ID --body "480cb033-9a92-4912-9d30-c6b7bf795a87"

# Remove the old credentials secret
gh secret delete AZURE_CREDENTIALS

# Verify the secrets are set
gh secret list
```

## Alternative: Manual GitHub Secrets Setup

If you prefer the web interface:

1. Go to: <https://github.com/srnichols/StampsPattern/settings/secrets/actions>

2. **Delete** the old secret:
   - Click on `AZURE_CREDENTIALS` and delete it

3. **Add** these three new secrets by clicking "New repository secret":

   **Secret Name:** `AZURE_CLIENT_ID`  
   **Value:** `e691193e-4e25-4a72-9185-1ce411aa2fd8`

   **Secret Name:** `AZURE_TENANT_ID`  
   **Value:** `16b3c013-d300-468d-ac64-7eda0820b6d3`

   **Secret Name:** `AZURE_SUBSCRIPTION_ID`  
   **Value:** `480cb033-9a92-4912-9d30-c6b7bf795a87`

## Quick Azure Portal Links

- **App Registration:** <https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Credentials/appId/e691193e-4e25-4a72-9185-1ce411aa2fd8>
- **Federated Credentials Tab:** Click "Certificates & secrets" → "Federated credentials" → "Add credential"

## Federated Credential Settings

When adding the federated credential in Azure Portal:

- **Scenario:** GitHub Actions deploying Azure resources
- **Organization:** `srnichols`
- **Repository:** `StampsPattern`
- **Entity type:** Branch
- **Branch name:** `master`
- **Name:** `github-actions-stamps-oidc-master`
