# Azure Entra ID Authentication Verification

param(
    [string]$ClientSecret
)

Write-Host "🔍 Verifying Azure Entra ID Authentication Configuration..." -ForegroundColor Cyan
Write-Host ""

# Configuration details

$portalUrl = "https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io"
$clientId = "d8f3024a-0c6a-4cea-af8b-7a7cd985354f"
$tenantId = "30dd575a-bca7-491b-adf6-41d5f39275d4"
$tenant = "Azurestamparch.onmicrosoft.com"

Write-Host "📋 Current Configuration:" -ForegroundColor Yellow
Write-Host "Portal URL: $portalUrl" -ForegroundColor White
Write-Host "Client ID: $clientId" -ForegroundColor White
Write-Host "Tenant ID: $tenantId" -ForegroundColor White
Write-Host "Tenant Domain: $tenant" -ForegroundColor White
Write-Host ""

# Check Container App environment variables

Write-Host "🔧 Checking Container App Configuration..." -ForegroundColor Yellow
try {
    $envVars = az containerapp show --name ca-stamps-portal --resource-group rg-stamps-mgmt --query "properties.template.containers[0].env" -o json | ConvertFrom-Json

    $azureAdVars = $envVars | Where-Object { $_.name -like "AzureAd__*" }
    
    if ($azureAdVars.Count -gt 0) {
        Write-Host "✅ Azure AD environment variables configured:" -ForegroundColor Green
        foreach ($var in $azureAdVars) {
            if ($var.secretRef) {
                Write-Host "   $($var.name): [SECRET REFERENCE]" -ForegroundColor Cyan
            } else {
                Write-Host "   $($var.name): $($var.value)" -ForegroundColor White
            }
        }
    } else {
        Write-Host "❌ No Azure AD environment variables found" -ForegroundColor Red
    }
} catch {
    Write-Error "Failed to check container app configuration: $_"
}

Write-Host ""

# Update client secret if provided

if ($ClientSecret) {
    Write-Host "🔐 Updating client secret..." -ForegroundColor Yellow
    try {
        az containerapp secret set --name ca-stamps-portal --resource-group rg-stamps-mgmt --secrets "azure-client-secret=$ClientSecret"
        Write-Host "✅ Client secret updated successfully!" -ForegroundColor Green
    } catch {
        Write-Error "Failed to update client secret: $_"
    }
    Write-Host ""
}

# Required redirect URIs check

Write-Host "🌐 Required Redirect URI Configuration:" -ForegroundColor Yellow
Write-Host "Please ensure these URIs are configured in your Enterprise Application:" -ForegroundColor White
Write-Host ""
Write-Host "Redirect URI:" -ForegroundColor Cyan
Write-Host "   $portalUrl/signin-oidc" -ForegroundColor White
Write-Host ""
Write-Host "Sign-out URL:" -ForegroundColor Cyan  
Write-Host "   $portalUrl/signout-callback-oidc" -ForegroundColor White
Write-Host ""

# Test authentication endpoint

Write-Host "🧪 Testing Authentication Endpoints..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Portal URL:" -ForegroundColor Cyan
Write-Host "   $portalUrl" -ForegroundColor White
Write-Host ""

Write-Host "OIDC Configuration URL:" -ForegroundColor Cyan
$oidcConfigUrl = "https://login.microsoftonline.com/$tenantId/v2.0/.well-known/openid-configuration"
Write-Host "   $oidcConfigUrl" -ForegroundColor White
Write-Host ""

# Test OIDC configuration

Write-Host "Testing OIDC endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri $oidcConfigUrl -Method Get -TimeoutSec 10
    if ($response.authorization_endpoint) {
        Write-Host "✅ OIDC configuration accessible" -ForegroundColor Green
        Write-Host "   Authorization endpoint: $($response.authorization_endpoint)" -ForegroundColor White
    }
} catch {
    Write-Host "⚠️  Could not verify OIDC configuration: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎯 Next Steps:" -ForegroundColor Yellow
if (-not $ClientSecret) {
    Write-Host "1. ❗ Generate and provide the client secret" -ForegroundColor Red
    Write-Host "   Run: .\verify-auth.ps1 -ClientSecret 'YOUR_SECRET_HERE'" -ForegroundColor White
}
Write-Host "2. ✅ Verify redirect URIs are configured in Azure Portal" -ForegroundColor Green
Write-Host "3. 🌐 Test authentication by visiting: $portalUrl" -ForegroundColor Cyan
Write-Host "4. 👤 Sign in with your Azure AD credentials" -ForegroundColor White

Write-Host ""
Write-Host "🔍 Manual Verification Steps:" -ForegroundColor Yellow
Write-Host "1. Browse to: $portalUrl" -ForegroundColor White
Write-Host "2. You should be redirected to Microsoft sign-in" -ForegroundColor White
Write-Host "3. Sign in with credentials from: $tenant" -ForegroundColor White
Write-Host "4. After authentication, you should return to the portal" -ForegroundColor White
Write-Host ""
