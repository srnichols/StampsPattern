# Fix Conditional Access Policy Blocking GitHub Actions

## Problem

GitHub Actions is being blocked by Azure AD Conditional Access policies with error:

```
AADSTS53003: Access has been blocked by Conditional Access policies. The access policy does not allow token issuance.
```

## Root Cause

Your organization's Azure AD tenant (Microsoft Non-Production) has Conditional Access policies that prevent service principals from authenticating from external locations like GitHub Actions runners.

## Solutions

### Solution 1: Request Conditional Access Policy Exception

Contact your Azure AD administrator to:

1. Create an exception for the `github-actions-stamps` service principal
2. Allow authentication from GitHub Actions IP ranges
3. Exclude service principals from location-based Conditional Access policies

### Solution 2: Use Azure CLI with Managed Identity (Alternative)

If available, switch to using Azure CLI with managed identity or federated credentials.

### Solution 3: Switch to OIDC Authentication (Recommended)

OIDC (OpenID Connect) authentication is often exempted from Conditional Access policies:

#### Step 1: Configure OIDC in Azure

1. Go to Azure Portal → Azure Active Directory → App registrations
2. Find `github-actions-stamps` app registration
3. Go to **Certificates & secrets**
4. Click **Federated credentials** tab
5. Click **Add credential**
6. Choose **GitHub Actions deploying Azure resources**
7. Fill in:
   - **Organization**: `srnichols`
   - **Repository**: `StampsPattern`
   - **Entity type**: `Branch`
   - **GitHub branch name**: `master`
   - **Name**: `github-actions-stamps-oidc`
8. Click **Add**

#### Step 2: Update GitHub Secrets

Remove the current `AZURE_CREDENTIALS` secret and add these instead:

- `AZURE_CLIENT_ID`: `e691193e-4e25-4a72-9185-1ce411aa2fd8`
- `AZURE_TENANT_ID`: `16b3c013-d300-468d-ac64-7eda0820b6d3`
- `AZURE_SUBSCRIPTION_ID`: `480cb033-9a92-4912-9d30-c6b7bf795a87`

#### Step 3: Update GitHub Workflow

Replace the Azure login step with OIDC authentication:

```yaml
- name: Azure Login
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

### Solution 4: Contact IT Administrator

Your organization's IT team needs to either:

1. Add `github-actions-stamps` to Conditional Access policy exclusions
2. Allow service principal authentication from GitHub Actions IP ranges
3. Provide alternative authentication method for CI/CD

## Immediate Actions

1. **Check role assignment** - Verify Contributor role is properly assigned
2. **Try OIDC approach** - Often bypasses Conditional Access policies
3. **Contact IT support** - Request exception for GitHub Actions automation

## GitHub Actions IP Ranges (for IT team)

If your IT team needs to allowlist GitHub Actions IPs:

- <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-githubs-ip-addresses>

## Status Check

After implementing any solution:

1. Push a test commit
2. Check GitHub Actions workflow logs
3. Verify authentication succeeds without Conditional Access errors
---

**📝 Document Version Information**
- **Version**: 1.3.0
- **Last Updated**: 2025-08-18 01:28:00 UTC  
- **Status**: Current
- **Next Review**: 2025-11