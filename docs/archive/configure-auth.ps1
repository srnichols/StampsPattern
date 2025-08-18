# Configure Azure Entra ID Authentication

# Run this script after completing the app registration in Azure Portal

param(
    [Parameter(Mandatory=$true)]
    [string]$ClientId,

    [Parameter(Mandatory=$true)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientSecret,
    
    [string]$ResourceGroup = "rg-stamps-mgmt"
)

Write-Host "🔐 Configuring Azure Entra ID Authentication..." -ForegroundColor Cyan

# Update the Container App with authentication configuration

Write-Host "Updating Container App secrets..." -ForegroundColor Yellow

try {
    # Update the azure-client-secret
    az containerapp secret set `
--name ca-stamps-portal `
        --resource-group $ResourceGroup `
        --secrets azure-client-secret=$ClientSecret

    # Update environment variables
    az containerapp update `
        --name ca-stamps-portal `
        --resource-group $ResourceGroup `
        --set-env-vars `
            "AzureAd__ClientId=$ClientId" `
            "AzureAd__TenantId=$TenantId" `
            "AzureAd__Instance=https://login.microsoftonline.com/" `
            "AzureAd__CallbackPath=/signin-oidc" `
            "AzureAd__SignedOutCallbackPath=/signout-callback-oidc"

    Write-Host "✅ Authentication configuration completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 Portal URL: https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📋 Verification Steps:" -ForegroundColor Yellow
    Write-Host "1. Navigate to the portal URL above" -ForegroundColor White
    Write-Host "2. You should be redirected to Microsoft sign-in" -ForegroundColor White
    Write-Host "3. Sign in with your Azure AD credentials" -ForegroundColor White
    Write-Host "4. You should be redirected back to the portal" -ForegroundColor White
    
} catch {
    Write-Error "❌ Error configuring authentication: $_"
    exit 1
}
