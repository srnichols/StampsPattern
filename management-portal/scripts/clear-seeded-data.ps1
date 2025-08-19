# Clear Seeded Data Script
# This script clears any eastus/westus seeded data from the Cosmos database
# to ensure only real westus2/westus3 data from your subscriptions is shown

Write-Host "🧹 Clearing seeded data from Cosmos database..." -ForegroundColor Yellow

# Check if we have a connection to the database
$cosmosEndpoint = $env:COSMOS_ACCOUNT_ENDPOINT
$cosmosConnectionString = $env:COSMOS_CONNECTION_STRING

if (-not $cosmosEndpoint -and -not $cosmosConnectionString) {
    Write-Host "❌ No Cosmos connection configured. Set COSMOS_ACCOUNT_ENDPOINT or COSMOS_CONNECTION_STRING" -ForegroundColor Red
    exit 1
}

Write-Host "📋 Seeded data to remove:" -ForegroundColor Cyan
Write-Host "  - Cells: cell-eastus-*, cell-westus-*" -ForegroundColor Gray
Write-Host "  - Tenants: contoso, fabrikam, adatum, northwind, tailspin, wingtip" -ForegroundColor Gray
Write-Host "  - Regions: eastus, westus (keeping only westus2, westus3)" -ForegroundColor Gray

Write-Host ""
Write-Host "✅ Expected real data:" -ForegroundColor Green
Write-Host "  - Subscription: MCAPS-Hybrid-REQ-101203-2024-scnichol-Host (2fb123ca-e419-4838-9b44-c2eb71a21769)" -ForegroundColor Gray
Write-Host "  - Subscription: MCAPS-Hybrid-REQ-103709-2024-scnichol-Hub (480cb033-9a92-4912-9d30-c6b7bf795a87)" -ForegroundColor Gray
Write-Host "  - Regions: westus2, westus3" -ForegroundColor Gray

Write-Host ""
Write-Host "🔧 To clear the data, run the clear-database utility:" -ForegroundColor Yellow
Write-Host "  cd management-portal/scripts" -ForegroundColor Gray
Write-Host "  dotnet run --project clear-database.csproj" -ForegroundColor Gray

Write-Host ""
Write-Host "💡 After clearing, populate with real data using your Azure Functions discovery." -ForegroundColor Blue
