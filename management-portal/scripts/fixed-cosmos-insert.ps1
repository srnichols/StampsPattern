# Fixed Cosmos DB data insertion using correct Azure CLI syntax
Write-Host "Starting Cosmos DB data insertion with correct CLI syntax..." -ForegroundColor Green

$resourceGroup = "rg-stamps-mgmt"
$cosmosAccount = "cosmos-xgjwtecm3g5pi"
$databaseName = "stamps-control-plane"

# Verify connection
Write-Host "Verifying Cosmos DB connection..." -ForegroundColor Yellow
try {
    $cosmosInfo = az cosmosdb show -g $resourceGroup -n $cosmosAccount | ConvertFrom-Json
    Write-Host "✓ Connected to Cosmos DB: $($cosmosInfo.name)" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to connect to Cosmos DB" -ForegroundColor Red
    exit 1
}

# Create sample cell document
Write-Host "`nInserting sample cell..." -ForegroundColor Yellow
$cellDoc = @{
    id = "cell-eastus-01"
    cellId = "cell-eastus-01"
    cellName = "East US Cell 01"
    region = "eastus"
    backendPool = "eastus-pool-01.stamps.com"
    maxCapacity = 1000
    currentTenants = 2
    isActive = $true
    cellType = "Standard"
    complianceFeatures = @("SOC2", "GDPR")
    healthStatus = "Healthy"
    lastHealthCheck = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    deploymentDate = (Get-Date).AddDays(-30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    maintenanceWindow = "02:00-04:00 UTC"
} | ConvertTo-Json -Depth 10

$tempFile1 = "$env:TEMP\cell.json"
$cellDoc | Out-File -FilePath $tempFile1 -Encoding utf8

try {
    az cosmosdb sql container item upsert --resource-group $resourceGroup --account-name $cosmosAccount --database-name $databaseName --container-name "cells" --body "@$tempFile1"
    Write-Host "✓ Inserted cell: East US Cell 01" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to insert cell" -ForegroundColor Red
}

# Create sample tenant document
Write-Host "`nInserting sample tenant..." -ForegroundColor Yellow
$tenantDoc = @{
    id = "tenant-techstartup"
    tenantId = "tenant-techstartup"
    subdomain = "techstartup"
    cellBackendPool = "eastus-pool-01.stamps.com"
    cellName = "East US Cell 01"
    region = "eastus"
    tenantTier = "Startup"
    isActive = $true
    createdDate = (Get-Date).AddDays(-15).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    contactEmail = "admin@techstartup.com"
    organizationName = "Tech Startup Inc"
    businessSegment = "SaaS Technology"
    complianceRequirements = @("SOC2")
    dataResidencyRequirements = @("United States")
    performanceRequirements = @{
        maxLatency = "100ms"
        throughputTarget = "1000rps"
        availabilityTarget = "99.9%"
    }
} | ConvertTo-Json -Depth 10

$tempFile2 = "$env:TEMP\tenant.json"
$tenantDoc | Out-File -FilePath $tempFile2 -Encoding utf8

try {
    az cosmosdb sql container item upsert --resource-group $resourceGroup --account-name $cosmosAccount --database-name $databaseName --container-name "tenants" --body "@$tempFile2"
    Write-Host "✓ Inserted tenant: Tech Startup Inc" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to insert tenant" -ForegroundColor Red
}

# Create sample operation document
Write-Host "`nInserting sample operation..." -ForegroundColor Yellow
$operationDoc = @{
    id = "op-001"
    tenantId = "tenant-techstartup"
    operationId = "op-001"
    operationType = "TenantCreation"
    status = "Completed"
    cellId = "cell-eastus-01"
    startTime = (Get-Date).AddDays(-15).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    endTime = (Get-Date).AddDays(-15).AddMinutes(5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    message = "Successfully created tenant techstartup in East US Cell 01"
} | ConvertTo-Json -Depth 10

$tempFile3 = "$env:TEMP\operation.json"
$operationDoc | Out-File -FilePath $tempFile3 -Encoding utf8

try {
    az cosmosdb sql container item upsert --resource-group $resourceGroup --account-name $cosmosAccount --database-name $databaseName --container-name "operations" --body "@$tempFile3"
    Write-Host "✓ Inserted operation: TenantCreation" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to insert operation" -ForegroundColor Red
}

# Add second cell
Write-Host "`nInserting additional sample data..." -ForegroundColor Yellow

$cell2Doc = @{
    id = "cell-westus-01"
    cellId = "cell-westus-01"
    cellName = "West US Cell 01"
    region = "westus"
    backendPool = "westus-pool-01.stamps.com"
    maxCapacity = 2000
    currentTenants = 1
    isActive = $true
    cellType = "High Performance"
    complianceFeatures = @("SOC2", "HIPAA", "FedRAMP")
    healthStatus = "Healthy"
    lastHealthCheck = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    deploymentDate = (Get-Date).AddDays(-45).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    maintenanceWindow = "03:00-05:00 UTC"
} | ConvertTo-Json -Depth 10

$tempFile4 = "$env:TEMP\cell2.json"
$cell2Doc | Out-File -FilePath $tempFile4 -Encoding utf8

try {
    az cosmosdb sql container item upsert --resource-group $resourceGroup --account-name $cosmosAccount --database-name $databaseName --container-name "cells" --body "@$tempFile4"
    Write-Host "✓ Inserted cell: West US Cell 01" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to insert second cell" -ForegroundColor Red
}

# Add second tenant
$tenant2Doc = @{
    id = "tenant-healthcorp"
    tenantId = "tenant-healthcorp"
    subdomain = "healthcorp"
    cellBackendPool = "westus-pool-01.stamps.com"
    cellName = "West US Cell 01"
    region = "westus"
    tenantTier = "Enterprise"
    isActive = $true
    createdDate = (Get-Date).AddDays(-30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    contactEmail = "admin@healthcorp.com"
    organizationName = "HealthCorp Medical Systems"
    businessSegment = "Healthcare"
    complianceRequirements = @("HIPAA", "SOC2")
    dataResidencyRequirements = @("United States")
    performanceRequirements = @{
        maxLatency = "50ms"
        throughputTarget = "5000rps"
        availabilityTarget = "99.99%"
    }
} | ConvertTo-Json -Depth 10

$tempFile5 = "$env:TEMP\tenant2.json"
$tenant2Doc | Out-File -FilePath $tempFile5 -Encoding utf8

try {
    az cosmosdb sql container item upsert --resource-group $resourceGroup --account-name $cosmosAccount --database-name $databaseName --container-name "tenants" --body "@$tempFile5"
    Write-Host "✓ Inserted tenant: HealthCorp Medical Systems" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to insert second tenant" -ForegroundColor Red
}

# Cleanup temp files
Remove-Item $tempFile1, $tempFile2, $tempFile3, $tempFile4, $tempFile5 -ErrorAction SilentlyContinue

Write-Host "`nData insertion completed!" -ForegroundColor Green
Write-Host "Verifying data was inserted..." -ForegroundColor Yellow

# Verify data was inserted
Write-Host "`nVerifying cells..." -ForegroundColor Cyan
az cosmosdb sql container item list --resource-group $resourceGroup --account-name $cosmosAccount --database-name $databaseName --container-name "cells" --query "length(@)"

Write-Host "`nVerifying tenants..." -ForegroundColor Cyan
az cosmosdb sql container item list --resource-group $resourceGroup --account-name $cosmosAccount --database-name $databaseName --container-name "tenants" --query "length(@)"

Write-Host "`nVerifying operations..." -ForegroundColor Cyan
az cosmosdb sql container item list --resource-group $resourceGroup --account-name $cosmosAccount --database-name $databaseName --container-name "operations" --query "length(@)"

Write-Host "`nData verification completed!" -ForegroundColor Green
