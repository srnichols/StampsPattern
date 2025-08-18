# !/usr/bin/env pwsh
param(
    [string]$ClientSecret = ""
)

Write-Host "🔐 Final Authentication Test" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

$portalUrl = "https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io"
$clientId = "d8f3024a-0c6a-4cea-af8b-7a7cd985354f"
$tenantId = "30dd575a-bca7-491b-adf6-41d5f39275d4"

Write-Host "🌐 Testing Portal Accessibility..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri $portalUrl -Method HEAD -UseBasicParsing 2>$null
    Write-Host "✅ Portal is accessible (Status: $($response.StatusCode))" -ForegroundColor Green

    # Check if we get redirect to Azure AD
    if ($response.StatusCode -eq 302) {
        $location = $response.Headers.Location
        if ($location -match "login.microsoftonline.com") {
            Write-Host "✅ Portal redirects to Azure AD authentication" -ForegroundColor Green
            
            # Check if redirect URI uses HTTPS
            if ($location -match "redirect_uri=https%3A%2F%2F") {
                Write-Host "✅ Redirect URI uses HTTPS" -ForegroundColor Green
            } else {
                Write-Host "❌ Redirect URI still using HTTP - container update may be in progress" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ Portal not redirecting to Azure AD" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Portal not requiring authentication (Status: $($response.StatusCode))" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Portal not accessible: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "🔍 Checking Container App Status..." -ForegroundColor Yellow
try {
    $caStatus = az containerapp show --name ca-stamps-portal --resource-group rg-stamps-mgmt --query "properties.runningStatus" -o tsv 2>$null
    Write-Host "✅ Container App Status: $caStatus" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to check Container App status: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "🔑 Manual Azure AD Configuration Required:" -ForegroundColor Yellow
Write-Host "===========================================" -ForegroundColor Yellow
Write-Host "1. Open: <https://portal.azure.com>" -ForegroundColor White
Write-Host "2. Navigate to: Azure Entra ID → App registrations" -ForegroundColor White
Write-Host "3. Find: StampsManagementClient ($clientId)" -ForegroundColor White
Write-Host "4. Go to: Authentication" -ForegroundColor White
Write-Host "5. Check 'ID tokens (used for implicit and hybrid flows)'" -ForegroundColor White
Write-Host "6. Add redirect URI: $portalUrl/signin-oidc" -ForegroundColor White
Write-Host "7. Save changes" -ForegroundColor White
Write-Host "8. Go to: Certificates & secrets" -ForegroundColor White
Write-Host "9. Create new client secret" -ForegroundColor White
Write-Host "10. Copy the secret value" -ForegroundColor White

if ($ClientSecret) {
    Write-Host ""
    Write-Host "🔐 Updating Container App Secret..." -ForegroundColor Yellow
    try {
        az containerapp secret set --name ca-stamps-portal --resource-group rg-stamps-mgmt --secrets "azure-client-secret=$ClientSecret" | Out-Null
        Write-Host "✅ Container App secret updated!" -ForegroundColor Green
        Write-Host "⏳ Waiting for container restart..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
    } catch {
        Write-Host "❌ Failed to update secret: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "🎯 Final Test Instructions:" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green
Write-Host "1. Wait 5-10 minutes for all changes to propagate" -ForegroundColor White
Write-Host "2. Open incognito browser window" -ForegroundColor White
Write-Host "3. Navigate to: $portalUrl" -ForegroundColor White
Write-Host "4. Should redirect to Microsoft sign-in" -ForegroundColor White
Write-Host "5. Use Azurestamparch.onmicrosoft.com account" -ForegroundColor White
Write-Host "6. Should successfully authenticate and return to portal" -ForegroundColor White
Write-Host ""
Write-Host "📚 Documentation:" -ForegroundColor Cyan
Write-Host "   docs/FIX_AADSTS700054.md - Detailed troubleshooting" -ForegroundColor White
Write-Host "   docs/AZURE_ENTRA_SETUP.md - Complete setup guide" -ForegroundColor White
