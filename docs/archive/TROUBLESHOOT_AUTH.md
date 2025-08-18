# Azure Stamps Portal Authentication Troubleshooting Guide

## 🎉 **AUTHENTICATION ISSUE RESOLVED**

**Status**: ✅ **RESOLVED** - August 14, 2025  
**Portal URL**: <https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io>  
**Solution Applied**: Enabled ID token issuance in app registration via Azure CLI  

### 🚀 **Final Working Configuration**

- **Application (client) ID**: `6458a4c9-082a-4b38-a3d0-d7100accacd4`
- **Directory (tenant) ID**: `30dd575a-bca7-491b-adf6-41d5f39275d4`  
- **ID Token Enabled**: ✅ **True** (Fixed AADSTS700054)
- **Sign-in Audience**: ✅ **AzureADMultipleOrgs** (Multi-tenant)
- **Login Status**: ✅ **Working Successfully**

### 🎯 **Root Cause & Solution**

The infinite redirect loop was caused by **AADSTS700054** error where ID token issuance was disabled in the app registration. This was resolved by:

```bash
# Commands used to fix the issue:
az ad app update --id "6458a4c9-082a-4b38-a3d0-d7100accacd4" --enable-id-token-issuance
az ad app update --id "6458a4c9-082a-4b38-a3d0-d7100accacd4" --sign-in-audience "AzureADMultipleOrgs"
```

**Key Success Factor**: Using Azure CLI to bypass Azure Portal UI bugs that prevented saving authentication settings.

---

## 🚨 **HISTORICAL: Authentication Troubleshooting Guide**

*Note: The issues below have been resolved. This section is kept for reference.*

## 🔍 Root Cause Analysis

The Azure AD application registration for the Stamps Portal doesn't exist in your current tenant. We need to create a new app registration.

## 🛠️ IMMEDIATE SOLUTION - Create New App Registration

### Step 1: Create App Registration in Azure Portal

1. **Navigate to Azure Portal**:
   - Go to [Azure Portal](https://portal.azure.com)
   - Sign in with your account

2. **Create New App Registration**:
   - Go to **Azure Active Directory** > **App registrations**
   - Click **"+ New registration"**
   - Use these settings:
     - **Name**: `StampsPortal-$(Get-Date -Format 'yyyyMMdd')`
     - **Supported account types**: `Accounts in this organizational directory only (Single tenant)`
     - **Redirect URI**:
       - Platform: `Web`
       - URI: `https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io/signin-oidc`

3. **Configure Authentication**:
   - After creation, go to **Authentication**
   - Under **Web** section, add:
     - **Redirect URIs**: `https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io/signin-oidc`
     - **Logout URL**: `https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io/signout-callback-oidc`
   - Under **Implicit grant and hybrid flows**: Check both boxes for tokens

4. **Create Client Secret**:
   - Go to **Certificates & secrets**
   - Click **"+ New client secret"**
   - Description: `StampsPortal Secret`
   - Expires: Choose appropriate timeframe (6 months or 1 year recommended)
   - **IMPORTANT**: Copy the secret value immediately - you won't be able to see it again!

5. **Note Down These Values**:
   - **Application (client) ID** (from Overview page)
   - **Directory (tenant) ID** (from Overview page)
   - **Client secret value** (from step 4)

### Step 2: Update Container App with New Values

Once you have the new app registration details, run these commands:

```bash
# Replace these with your actual values from the app registration
$newClientId = "YOUR_NEW_CLIENT_ID_HERE"
$newClientSecret = "YOUR_NEW_CLIENT_SECRET_HERE"  
$tenantId = "16b3c013-d300-468d-ac64-7eda0820b6d3"

# Update the client secret in the container app
az containerapp secret set --name ca-stamps-portal --resource-group rg-stamps-mgmt --secrets azure-client-secret=$newClientSecret

# Update the environment variables
az containerapp update --name ca-stamps-portal --resource-group rg-stamps-mgmt --set-env-vars AzureAd__ClientId=$newClientId AzureAd__TenantId=$tenantId
```

### Step 3: Test the Solution

After updating the container app:

1. Wait 2-3 minutes for the changes to propagate
2. Navigate to: <https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io>
3. Try to log in with your Microsoft account

## 🆘 ALTERNATIVE SOLUTION - Use Easy Auth

If you continue having issues with app registration, we can configure authentication directly on the Container App:

```bash
# Enable Easy Auth on the container app
az containerapp auth update --name ca-stamps-portal --resource-group rg-stamps-mgmt \
  --action LoginWithAzureActiveDirectory \
  --aad-tenant-id "16b3c013-d300-468d-ac64-7eda0820b6d3" \
  --aad-client-id "YOUR_CLIENT_ID" \
  --aad-client-secret "YOUR_CLIENT_SECRET"
```

### Step 1: Check App Registration Configuration in Azure Portal

1. **Navigate to Azure Portal**:
   - Go to [Azure Portal](https://portal.azure.com)
   - Sign in with an account that has admin privileges in the tenant

2. **Find the App Registration**:
   - Go to **Azure Active Directory** > **App registrations**
   - Search for "StampsPortal" or similar name
   - Click on the app registration

3. **Verify Essential Settings**:

   #### A. Authentication Configuration

   - **Supported account types** should be one of:
     - `Accounts in any organizational directory (Any Azure AD directory - Multitenant)`
     - `Accounts in this organizational directory only (Single tenant)`

   #### B. Redirect URIs

   - **Platform**: Web
   - **Redirect URIs** should include:

     ```
     https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io/signin-oidc
     ```

   #### C. Logout URL

   - Should be set to:

     ```
     https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io/signout-callback-oidc
     ```

### Step 2: Fix Common Configuration Issues

#### Issue 1: Single Tenant vs Multi-Tenant

- **If targeting specific tenant**: Set to "Single tenant" and ensure it's in the correct tenant
- **If supporting multiple tenants**: Set to "Multitenant" and configure properly

#### Issue 2: Missing or Incorrect Redirect URIs

Add the correct redirect URI for your container app:

```
https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io/signin-oidc
```

#### Issue 3: Application ID URI

- Go to **Expose an API**
- Ensure the Application ID URI is set correctly
- Default should be: `api://{app-id}`

### Step 3: Container App Configuration

Check the environment variables in your container app:

```bash
az containerapp show --name ca-stamps-portal --resource-group rg-stamps-mgmt --query "properties.template.containers[0].env" -o table
```

Required environment variables:

- `AZURE_AD_TENANT_ID`: Should be the tenant ID for Azurestamparch.onmicrosoft.com
- `AZURE_AD_CLIENT_ID`: Application (client) ID from app registration
- `AZURE_AD_CLIENT_SECRET`: Client secret from app registration
- `AZURE_AD_INSTANCE`: Usually `https://login.microsoftonline.com/`
- `AZURE_AD_DOMAIN`: `Azurestamparch.onmicrosoft.com`

### Step 4: Verify Tenant Configuration

1. **Get the correct Tenant ID for Azurestamparch.onmicrosoft.com**:

   ```bash
   az account list --query "[?contains(name, 'Azurestamparch')].{name:name, tenantId:tenantId}" -o table
   ```

2. **Switch to the correct tenant if needed**:

   ```bash
   az account set --subscription "subscription-id-for-azurestamparch-tenant"
   ```

### Step 5: Update Container App Configuration

If you find configuration issues, update the container app:

```bash
# Update environment variables
az containerapp update --name ca-stamps-portal --resource-group rg-stamps-mgmt \
  --set-env-vars \
  AZURE_AD_TENANT_ID="correct-tenant-id" \
  AZURE_AD_CLIENT_ID="correct-client-id" \
  AZURE_AD_DOMAIN="Azurestamparch.onmicrosoft.com"
```

### Step 6: Alternative Authentication Methods

If the above doesn't work, consider:

1. **Recreate App Registration**:
   - Create a new app registration in the Azurestamparch.onmicrosoft.com tenant
   - Configure it properly for the container app
   - Update the container app with new credentials

2. **Use Azure Container Apps Easy Auth**:
   - Configure authentication directly on the container app
   - Bypass the application-level authentication

## 🔧 Quick Fixes to Try

### Fix 1: Update App Registration Redirect URI

In Azure Portal > App registrations > Your App > Authentication:

- Add redirect URI: `https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io/signin-oidc`

### Fix 2: Check Tenant Configuration

Ensure the app registration is in the same tenant as where you're trying to log in.

### Fix 3: Restart Container App

```bash
az containerapp revision restart --name ca-stamps-portal --resource-group rg-stamps-mgmt
```

## 📞 Next Steps

1. **Immediate**: Check the app registration configuration in Azure Portal
2. **Verify**: Ensure all redirect URIs are correctly configured
3. **Test**: Try logging in again after making configuration changes
4. **Monitor**: Check container app logs for any remaining errors

## 🔗 Additional Resources

- [Azure AD App Registration Documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [Container Apps Authentication](https://docs.microsoft.com/en-us/azure/container-apps/authentication)
- [OpenID Connect Authentication](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-protocols-oidc)

---

**Need immediate help?** Check the app registration settings first, as this is the most likely cause of the authentication error.
