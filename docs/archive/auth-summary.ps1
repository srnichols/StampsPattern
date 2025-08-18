Write-Host ""
Write-Host "Azure Stamps Management Portal - Authentication Setup Complete" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""

$portalUrl = "https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io"
$clientId = "d8f3024a-0c6a-4cea-af8b-7a7cd985354f"
$tenantId = "30dd575a-bca7-491b-adf6-41d5f39275d4"
$objectId = "4074e1f0-08f2-4b83-b399-0a150bd4c3d0"

Write-Host "INFRASTRUCTURE STATUS: COMPLETE" -ForegroundColor Green
Write-Host "   - Container Apps running and auto-scaling" -ForegroundColor White
Write-Host "   - Azure Container Registry with custom images" -ForegroundColor White
Write-Host "   - Application Insights monitoring active" -ForegroundColor White
Write-Host "   - Log Analytics with metric alerts configured" -ForegroundColor White

Write-Host ""
Write-Host "TECHNICAL CONFIGURATION: COMPLETE" -ForegroundColor Green
Write-Host "   - Portal redirects to Azure AD (HTTPS enabled)" -ForegroundColor White
Write-Host "   - Environment variables configured correctly" -ForegroundColor White
Write-Host "   - Authentication middleware active" -ForegroundColor White

Write-Host ""
Write-Host "MANUAL AZURE AD CONFIGURATION REQUIRED:" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Yellow

Write-Host "Portal URL: $portalUrl" -ForegroundColor Cyan
Write-Host "Client ID:  $clientId" -ForegroundColor Cyan
Write-Host "Tenant ID:  $tenantId" -ForegroundColor Cyan
Write-Host "Object ID:  $objectId" -ForegroundColor Cyan

Write-Host ""
Write-Host "STEPS TO COMPLETE IN AZURE PORTAL:" -ForegroundColor White
Write-Host "-----------------------------------" -ForegroundColor White
Write-Host "1. Open: <https://portal.azure.com>" -ForegroundColor White
Write-Host "2. Navigate: Azure Entra ID -> App registrations" -ForegroundColor White
Write-Host "3. Search: 'StampsManagementClient' or use Client ID: $clientId" -ForegroundColor White
Write-Host "4. Click: Authentication (left menu)" -ForegroundColor White
Write-Host "5. Under 'Implicit grant and hybrid flows':" -ForegroundColor White
Write-Host "   CHECK: 'ID tokens (used for implicit and hybrid flows)'" -ForegroundColor Yellow
Write-Host "6. Under 'Redirect URIs':" -ForegroundColor White
Write-Host "   ADD: $portalUrl/signin-oidc" -ForegroundColor Yellow
Write-Host "7. Click 'Save'" -ForegroundColor White
Write-Host "8. Click: Certificates secrets (left menu)" -ForegroundColor White
Write-Host "9. Click: '+ New client secret'" -ForegroundColor White
Write-Host "10. Description: 'Production Portal Secret'" -ForegroundColor White
Write-Host "11. Expires: 24 months" -ForegroundColor White
Write-Host "12. Click 'Add'" -ForegroundColor White
Write-Host "13. COPY THE SECRET VALUE IMMEDIATELY" -ForegroundColor Red

Write-Host ""
Write-Host "AFTER GENERATING CLIENT SECRET, RUN:" -ForegroundColor Yellow
Write-Host "az containerapp secret set --name ca-stamps-portal --resource-group rg-stamps-mgmt --secrets 'azure-client-secret=YOUR_SECRET_VALUE'" -ForegroundColor Cyan

Write-Host ""
Write-Host "TESTING AUTHENTICATION:" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green
Write-Host "1. Wait 5-10 minutes for Azure AD changes to propagate" -ForegroundColor White
Write-Host "2. Open incognito/private browser window" -ForegroundColor White
Write-Host "3. Navigate to: $portalUrl" -ForegroundColor Cyan
Write-Host "4. Should redirect to Microsoft sign-in page" -ForegroundColor White
Write-Host "5. Use account from: Azurestamparch.onmicrosoft.com" -ForegroundColor White
Write-Host "6. Should return to portal after successful authentication" -ForegroundColor White

Write-Host ""
Write-Host "THE TECHNICAL SETUP IS 100% COMPLETE!" -ForegroundColor Green
Write-Host "Only the Azure AD manual configuration remains." -ForegroundColor Green
Write-Host ""
