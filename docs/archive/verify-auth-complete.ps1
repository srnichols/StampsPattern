# Verify Azure AD Authentication Configuration

param(
    [string]$ClientSecret,
    [switch]$TestEndpoints = $true
)

Write-Host "🔍 Azure AD Authentication Configuration Verification" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

$portalUrl = "https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io"
$tenantId = "30dd575a-bca7-491b-adf6-41d5f39275d4"
$clientId = "d8f3024a-0c6a-4cea-af8b-7a7cd985354f"

# Update Container App Secret if provided
if ($ClientSecret) {
    Write-Host "🔐 Updating Container App Secret..." -ForegroundColor Yellow
    try {
        az containerapp secret set --name ca-stamps-portal --resource-group rg-stamps-mgmt --secrets "azure-client-secret=$ClientSecret"
        Write-Host "✅ Container App secret updated successfully!" -ForegroundColor Green
        
        # Wait for container restart
        Write-Host "⏳ Waiting for container to restart..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        
    } catch {
        Write-Host "❌ Failed to update container app secret: $_" -ForegroundColor Red
        return
    }
    Write-Host ""

# Test OIDC Configuration
if ($TestEndpoints) {
    Write-Host "🌐 Testing OIDC Configuration..." -ForegroundColor Yellow
    $oidcUrl = "https://login.microsoftonline.com/$tenantId/v2.0/.well-known/openid-configuration"
    
    try {
        $oidcConfig = Invoke-RestMethod -Uri $oidcUrl -Method Get -TimeoutSec 10
        Write-Host "✅ OIDC configuration accessible" -ForegroundColor Green
        Write-Host "   Authorization endpoint: $($oidcConfig.authorization_endpoint)" -ForegroundColor White
        Write-Host "   Token endpoint: $($oidcConfig.token_endpoint)" -ForegroundColor White
        
        # Test if the issuer matches our tenant
        if ($oidcConfig.issuer -like "*$tenantId*") {
            Write-Host "✅ Issuer matches expected tenant" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Issuer mismatch - check tenant configuration" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ OIDC configuration error: $_" -ForegroundColor Red
    }
    Write-Host ""
}

# Check Container App Status
Write-Host "🐳 Checking Container App Status..." -ForegroundColor Yellow
try {
    $appStatus = az containerapp show --name ca-stamps-portal --resource-group rg-stamps-mgmt --query "properties.runningStatus" -o tsv
    Write-Host "✅ Container App Status: $appStatus" -ForegroundColor Green
    
    # Check if authentication environment variables are set
    $envVars = az containerapp show --name ca-stamps-portal --resource-group rg-stamps-mgmt --query "properties.template.containers[0].env[?contains(name, 'AzureAd')].{name:name,value:value}" -o json | ConvertFrom-Json
    
    if ($envVars.Count -gt 0) {
        Write-Host "✅ Azure AD environment variables configured:" -ForegroundColor Green
        foreach ($var in $envVars) {
            Write-Host "   $($var.name): $($var.value)" -ForegroundColor White
        }
    } else {
        Write-Host "⚠️  No Azure AD environment variables found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Container App check failed: $_" -ForegroundColor Red
}
Write-Host ""

# Test Portal Accessibility
Write-Host "🌍 Testing Portal Accessibility..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri $portalUrl -Method Head -TimeoutSec 10 -MaximumRedirection 0 -ErrorAction SilentlyContinue
    
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Portal accessible directly (no authentication)" -ForegroundColor Green
    } elseif ($response.StatusCode -eq 302 -or $response.StatusCode -eq 301) {
        Write-Host "✅ Portal redirects (likely to authentication)" -ForegroundColor Green
        if ($response.Headers.Location) {
            Write-Host "   Redirect location: $($response.Headers.Location)" -ForegroundColor White
        }
    }
} catch {
    if ($_.Exception.Response.StatusCode -eq 302) {
        Write-Host "✅ Portal redirects to authentication" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Portal response: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
Write-Host ""

# Final Instructions
Write-Host "🎯 Manual Verification Steps:" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green
Write-Host "1. Open incognito/private browser window" -ForegroundColor White
Write-Host "2. Navigate to: $portalUrl" -ForegroundColor Cyan
Write-Host "3. Expected behavior:" -ForegroundColor White
Write-Host "   - Should redirect to Microsoft sign-in" -ForegroundColor White
Write-Host "   - Sign in with Azurestamparch.onmicrosoft.com credentials" -ForegroundColor White
Write-Host "   - Should return to portal after successful authentication" -ForegroundColor White
Write-Host ""

Write-Host "🔧 If authentication still fails:" -ForegroundColor Yellow
Write-Host "1. Verify ID tokens are enabled in Azure Portal" -ForegroundColor White
Write-Host "2. Check redirect URIs are configured correctly" -ForegroundColor White
Write-Host "3. Ensure client secret is valid and not expired" -ForegroundColor White
Write-Host "4. Wait 10-15 minutes for Azure AD changes to propagate" -ForegroundColor White

Write-Host ""
Write-Host "📖 Reference Documentation:" -ForegroundColor Cyan
Write-Host "docs/MANUAL_AUTH_FIX.md - Complete step-by-step guide" -ForegroundColor White
Write-Host "docs/FIX_AADSTS700054.md - Specific error fix details" -ForegroundColor White

Write-Host ""
