# Azure AD Authentication Fix - Complete Configuration Script

# This script provides both manual steps and CLI commands (requires admin privileges)

param(
    [string]$ClientSecret,
    [switch]$UseManualSteps = $true
)

Write-Host "🔐 Azure AD Authentication Configuration Script" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Configuration details

$appObjectId = "4074e1f0-08f2-4b83-b399-0a150bd4c3d0"
$clientId = "d8f3024a-0c6a-4cea-af8b-7a7cd985354f"
$tenantId = "30dd575a-bca7-491b-adf6-41d5f39275d4"
$portalUrl = "<https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io>"
$redirectUri = "$portalUrl/signin-oidc"
$logoutUrl = "$portalUrl/signout-callback-oidc"

Write-Host "📋 Configuration Details:" -ForegroundColor Yellow
Write-Host "App Object ID: $appObjectId" -ForegroundColor White
Write-Host "Client ID: $clientId" -ForegroundColor White
Write-Host "Tenant ID: $tenantId" -ForegroundColor White
Write-Host "Portal URL: $portalUrl" -ForegroundColor White
Write-Host "Redirect URI: $redirectUri" -ForegroundColor White
Write-Host "Logout URL: $logoutUrl" -ForegroundColor White
Write-Host ""

if ($UseManualSteps) {
    Write-Host "🔧 MANUAL STEPS (Recommended - No special permissions needed):" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""

    Write-Host "1. 🌐 Open Azure Portal:" -ForegroundColor Yellow
    Write-Host "   https://portal.azure.com" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "2. 📁 Navigate to Azure Entra ID:" -ForegroundColor Yellow
    Write-Host "   Azure Portal → Azure Entra ID → App registrations" -ForegroundColor White
    Write-Host ""
    
    Write-Host "3. 🔍 Find Your Application:" -ForegroundColor Yellow
    Write-Host "   Search for Client ID: $clientId" -ForegroundColor Cyan
    Write-Host "   Or search for: StampsManagementClient" -ForegroundColor White
    Write-Host ""
    
    Write-Host "4. ⚙️ Configure Authentication:" -ForegroundColor Yellow
    Write-Host "   Click on your app → Authentication (left menu)" -ForegroundColor White
    Write-Host ""
    Write-Host "   A. Web Redirect URIs:" -ForegroundColor Cyan
    Write-Host "      Add: $redirectUri" -ForegroundColor White
    Write-Host ""
    Write-Host "   B. Logout URL:" -ForegroundColor Cyan
    Write-Host "      Add: $logoutUrl" -ForegroundColor White
    Write-Host ""
    Write-Host "   C. Implicit Grant Settings:" -ForegroundColor Cyan
    Write-Host "      ✅ Check: ID tokens (used for implicit and hybrid flows)" -ForegroundColor Green
    Write-Host "      ✅ Check: Access tokens (used for implicit flows)" -ForegroundColor Green
    Write-Host ""
    Write-Host "   D. Click SAVE" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "5. 🔑 Generate Client Secret:" -ForegroundColor Yellow
    Write-Host "   Certificates & secrets → New client secret" -ForegroundColor White
    Write-Host "   Copy the secret value immediately!" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "6. 🔒 Optional - API Permissions:" -ForegroundColor Yellow
    Write-Host "   API permissions → Add Microsoft Graph permissions:" -ForegroundColor White
    Write-Host "   - openid (should already exist)" -ForegroundColor White
    Write-Host "   - profile" -ForegroundColor White
    Write-Host "   - email" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "🤖 ATTEMPTING AUTOMATED CONFIGURATION:" -ForegroundColor Yellow
    Write-Host "=====================================" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Trying to update app registration..." -ForegroundColor Yellow
    
    # Try to enable ID tokens
    try {
        Write-Host "Enabling ID token issuance..." -ForegroundColor Yellow
        az ad app update --id $clientId --enable-id-token-issuance true --enable-access-token-issuance true
        Write-Host "✅ ID token issuance enabled!" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to enable ID tokens: $_" -ForegroundColor Red
        Write-Host "   You'll need to do this manually in Azure Portal" -ForegroundColor Yellow
    }
    
    # Try to update redirect URIs
    try {
        Write-Host "Configuring redirect URIs..." -ForegroundColor Yellow
        az ad app update --id $clientId --web-redirect-uris $redirectUri
        Write-Host "✅ Redirect URIs configured!" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to configure redirect URIs: $_" -ForegroundColor Red
        Write-Host "   You'll need to do this manually in Azure Portal" -ForegroundColor Yellow
    }
}

# Update Container App Secret

if ($ClientSecret) {
    Write-Host "7. 🐳 Updating Container App Secret..." -ForegroundColor Yellow
    try {
        az containerapp secret set --name ca-stamps-portal --resource-group rg-stamps-mgmt --secrets "azure-client-secret=$ClientSecret"
        Write-Host "✅ Container App secret updated!" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to update container app secret: $_" -ForegroundColor Red
    }
} else {
    Write-Host "7. 🐳 Update Container App Secret:" -ForegroundColor Yellow
    Write-Host "   After generating the client secret, run:" -ForegroundColor White
    Write-Host "   az containerapp secret set --name ca-stamps-portal --resource-group rg-stamps-mgmt --secrets azure-client-secret=`"YOUR-SECRET`"" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "🧪 TESTING STEPS:" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green
Write-Host "1. Wait 5-10 minutes after making changes" -ForegroundColor White
Write-Host "2. Open incognito/private browser" -ForegroundColor White
Write-Host "3. Navigate to: $portalUrl" -ForegroundColor Cyan
Write-Host "4. Should redirect to Microsoft sign-in" -ForegroundColor White
Write-Host "5. Sign in with Azurestamparch.onmicrosoft.com credentials" -ForegroundColor White
Write-Host "6. Should return to portal successfully" -ForegroundColor White

Write-Host ""
Write-Host "📖 REFERENCE LINKS:" -ForegroundColor Yellow
Write-Host "==================" -ForegroundColor Yellow
Write-Host "Azure Portal: <https://portal.azure.com>" -ForegroundColor Cyan
Write-Host "Your App Registration: <https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Authentication/appId/$clientId>" -ForegroundColor Cyan
Write-Host "Portal URL: $portalUrl" -ForegroundColor Cyan

Write-Host ""
Write-Host "✅ Once completed, your authentication should work!" -ForegroundColor Green
Write-Host ""
