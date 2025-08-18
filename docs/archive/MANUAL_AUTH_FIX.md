# 🎯 Azure AD Configuration - Step-by-Step Fix

## 🚨 IMMEDIATE ACTION REQUIRED

You have the `AADSTS700054` error because **ID tokens are not enabled** in your Azure AD application registration.

## 📋 **Manual Configuration Steps**

### **Step 1: Open Your App Registration**
1. **Navigate to**: https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Authentication/appId/d8f3024a-0c6a-4cea-af8b-7a7cd985354f
   
   **OR**
   
2. **Manual navigation**:
   - Azure Portal → Azure Entra ID → App registrations
   - Search for: `d8f3024a-0c6a-4cea-af8b-7a7cd985354f`
   - Click on your application

### **Step 2: Configure Authentication Settings**

Click "**Authentication**" in the left menu, then:

#### **A. Redirect URIs**
Under "Web" platform, add:
```
https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io/signin-oidc
```

#### **B. Logout URL** 
Add:
```
https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io/signout-callback-oidc
```

#### **C. Implicit Grant Settings** ⭐ **CRITICAL**
Under "Implicit grant and hybrid flows", check BOTH:
- ✅ **ID tokens (used for implicit and hybrid flows)**
- ✅ **Access tokens (used for implicit flows)**

#### **D. Save Changes**
Click **"Save"** button at the top

### **Step 3: Generate Client Secret**
1. Click **"Certificates & secrets"** in the left menu
2. Click **"New client secret"**
3. Add description: "Portal Authentication"
4. Select expiration (recommend 24 months)
5. Click **"Add"**
6. **⚠️ IMMEDIATELY COPY THE SECRET VALUE** - it won't be shown again

### **Step 4: Update Container App Secret**
Run this command with your actual secret:
```powershell
az containerapp secret set --name ca-stamps-portal --resource-group rg-stamps-mgmt --secrets azure-client-secret="YOUR-ACTUAL-CLIENT-SECRET"
```

## 🧪 **Test Authentication**

1. **Wait 5-10 minutes** for Azure AD changes to propagate
2. **Open incognito/private browser** window
3. **Navigate to**: https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io
4. **Expected flow**:
   - Should redirect to Microsoft sign-in
   - Sign in with credentials from: `Azurestamparch.onmicrosoft.com`
   - Should redirect back to portal successfully

## ✅ **Verification Checklist**

- [ ] ID tokens enabled in app registration
- [ ] Access tokens enabled in app registration  
- [ ] Redirect URI added correctly
- [ ] Logout URL added correctly
- [ ] Clicked "Save" in authentication settings
- [ ] Client secret generated and copied
- [ ] Container app secret updated with real value
- [ ] Waited 5-10 minutes for propagation
- [ ] Tested in incognito/private browser

---

**This will fix the AADSTS700054 error and enable authentication!** 🎉



