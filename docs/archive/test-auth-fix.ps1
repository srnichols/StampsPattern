# Test Authentication After AADSTS700054 Fix

Write-Host "🔍 Testing Authentication Configuration..." -ForegroundColor Cyan
Write-Host ""

$portalUrl = "https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io"
$clientId = "d8f3024a-0c6a-4cea-af8b-7a7cd985354f"
$tenantId = "30dd575a-bca7-491b-adf6-41d5f39275d4"

Write-Host "📋 Error Details:" -ForegroundColor Yellow
Write-Host "Error: AADSTS700054 - ID tokens not enabled" -ForegroundColor Red
Write-Host "Fix: Enable 'ID tokens' in app registration authentication settings" -ForegroundColor Green
Write-Host ""

# Test OIDC configuration
Write-Host "🌐 Testing OIDC Configuration..." -ForegroundColor Yellow
$oidcUrl = "https://login.microsoftonline.com/$tenantId/v2.0/.well-known/openid-configuration"

try {
    $oidcConfig = Invoke-RestMethod -Uri $oidcUrl -Method Get -TimeoutSec 10
    Write-Host "✅ OIDC endpoint accessible" -ForegroundColor Green
    Write-Host "   Authorization endpoint: $($oidcConfig.authorization_endpoint)" -ForegroundColor White
    Write-Host "   Token endpoint: $($oidcConfig.token_endpoint)" -ForegroundColor White
    Write-Host "   Issuer: $($oidcConfig.issuer)" -ForegroundColor White
} catch {
    Write-Host "❌ OIDC configuration error: $_" -ForegroundColor Red
}

Write-Host ""

# Check container app status
Write-Host "🐳 Checking Container App Status..." -ForegroundColor Yellow
try {
    $appStatus = az containerapp show --name ca-stamps-portal --resource-group rg-stamps-mgmt --query "properties.runningStatus" -o tsv
    Write-Host "✅ Container App Status: $appStatus" -ForegroundColor Green
} catch {
    Write-Host "❌ Container App check failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎯 Manual Test Steps:" -ForegroundColor Yellow
Write-Host "1. Complete the Azure Portal fix for ID tokens" -ForegroundColor White
Write-Host "2. Wait 5-10 minutes for Azure AD changes to propagate" -ForegroundColor White
Write-Host "3. Open incognito/private browser window" -ForegroundColor White
Write-Host "4. Navigate to: $portalUrl" -ForegroundColor Cyan
Write-Host "5. Should redirect to Microsoft sign-in" -ForegroundColor White
Write-Host "6. Sign in with Azurestamparch.onmicrosoft.com credentials" -ForegroundColor White
Write-Host "7. Should return to portal after authentication" -ForegroundColor White

Write-Host ""
Write-Host "📖 Full fix guide available in: docs/FIX_AADSTS700054.md" -ForegroundColor Cyan
Write-Host ""
