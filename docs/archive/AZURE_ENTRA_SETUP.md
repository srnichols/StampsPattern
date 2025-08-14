# Azure Entra ID Authentication Setup - CONFIGURED

## ✅ Your Current Configuration

**Enterprise Application Details:**
- **Name**: StampsManagementClient
- **Application ID**: d8f3024a-0c6a-4cea-af8b-7a7cd985354f
- **Object ID**: 4074e1f0-08f2-4b83-b399-0a150bd4c3d0
- **Tenant**: Azurestamparch.onmicrosoft.com
- **Tenant ID**: 30dd575a-bca7-491b-adf6-41d5f39275d4

**Portal Configuration**: ✅ **CONFIGURED**
- **Client ID**: d8f3024a-0c6a-4cea-af8b-7a7cd985354f
- **Tenant ID**: 30dd575a-bca7-491b-adf6-41d5f39275d4
- **Environment Variables**: All Azure AD settings applied to Container App

## 🔍 **Required Redirect URI Configuration**

**Please verify these URIs are configured in your Enterprise Application:**

1. **Navigate to Azure Portal** → Azure Entra ID → Enterprise Applications
2. **Find**: "StampsManagementClient" 
3. **Go to**: Single sign-on → Edit Basic SAML Configuration
4. **Ensure these Redirect URIs are configured:**

   ```
   https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io/signin-oidc
   ```

   **Sign-out URL:**
   ```
   https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io/signout-callback-oidc
   ```

## 🔐 **Missing: Client Secret Configuration**

**⚠️ IMPORTANT**: You need to update the client secret:

1. **Generate Client Secret** (if not already done):
   - Go to Azure Entra ID → App registrations
   - Find your app registration (not Enterprise Application)
   - Go to Certificates & secrets → New client secret
   - Copy the secret value

2. **Update Container App Secret**:
   ```powershell
   az containerapp secret set `
     --name ca-stamps-portal `
     --resource-group rg-stamps-mgmt `
     --secrets azure-client-secret="YOUR-ACTUAL-CLIENT-SECRET-HERE"
   ```

## 🚨 **CRITICAL: Enable ID Tokens**

**⚠️ AADSTS700054 Error Fix Required**:

Your application registration must have ID tokens enabled:

1. **Navigate to**: Azure Portal → Azure Entra ID → App registrations
2. **Find your app** using Client ID: `d8f3024a-0c6a-4cea-af8b-7a7cd985354f`
3. **Go to**: Authentication
4. **Under "Implicit grant and hybrid flows"**:
   - ✅ **Check "ID tokens (used for implicit and hybrid flows)"** ← **CRITICAL**
   - ✅ **Check "Access tokens (used for implicit flows)"** ← **RECOMMENDED**
5. **Click Save**

**Without this setting, you'll get authentication error AADSTS700054**
