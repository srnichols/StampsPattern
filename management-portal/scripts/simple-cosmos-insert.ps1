# Simple Cosmos DB data insertion using Azure CLI
Write-Host "Starting Cosmos DB data insertion using Azure CLI..." -ForegroundColor Green

# Check if logged in to Azure
try {
    $account = az account show 2>$null | ConvertFrom-Json
    Write-Host "✓ Logged in to Azure as: $($account.user.name)" -ForegroundColor Green
} catch {
    Write-Host "✗ Not logged in to Azure. Please run 'az login' first." -ForegroundColor Red
    exit 1
}

$resourceGroup = "rg-stamps-mgmt"
$cosmosAccount = "cosmos-xgjwtecm3g5pi"
$databaseName = "stamps-control-plane"

Write-Host "Creating containers if they don't exist..." -ForegroundColor Yellow

# Create containers
$containers = @("cells", "tenants", "operations")
foreach ($containerName in $containers) {
    Write-Host "Creating container: $containerName" -ForegroundColor Cyan
    az cosmosdb sql container create --name $containerName --resource-group $resourceGroup --account-name $cosmosAccount --database-name $databaseName --partition-key-path "/id" --throughput 400 2>$null
}

Write-Host "✓ Containers created" -ForegroundColor Green

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

az cosmosdb sql item create --resource-group $resourceGroup --account-name $cosmosAccount --database-name $databaseName --container-name "cells" --body "@$tempFile1"
Write-Host "✓ Inserted cell: East US Cell 01" -ForegroundColor Green

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

az cosmosdb sql item create --resource-group $resourceGroup --account-name $cosmosAccount --database-name $databaseName --container-name "tenants" --body "@$tempFile2"
Write-Host "✓ Inserted tenant: Tech Startup Inc" -ForegroundColor Green

# Create sample operation document
Write-Host "`nInserting sample operation..." -ForegroundColor Yellow
$operationDoc = @{
    id = "op-001"
    operationId = "op-001"
    operationType = "TenantCreation"
    status = "Completed"
    tenantId = "tenant-techstartup"
    cellId = "cell-eastus-01"
    startTime = (Get-Date).AddDays(-15).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    endTime = (Get-Date).AddDays(-15).AddMinutes(5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    message = "Successfully created tenant techstartup in East US Cell 01"
} | ConvertTo-Json -Depth 10

$tempFile3 = "$env:TEMP\operation.json"
$operationDoc | Out-File -FilePath $tempFile3 -Encoding utf8

az cosmosdb sql item create --resource-group $resourceGroup --account-name $cosmosAccount --database-name $databaseName --container-name "operations" --body "@$tempFile3"
Write-Host "✓ Inserted operation: TenantCreation" -ForegroundColor Green

# Add more data
Write-Host "`nInserting additional sample data..." -ForegroundColor Yellow

# Second cell
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

az cosmosdb sql item create --resource-group $resourceGroup --account-name $cosmosAccount --database-name $databaseName --container-name "cells" --body "@$tempFile4"
Write-Host "✓ Inserted cell: West US Cell 01" -ForegroundColor Green

# Second tenant
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

az cosmosdb sql item create --resource-group $resourceGroup --account-name $cosmosAccount --database-name $databaseName --container-name "tenants" --body "@$tempFile5"
Write-Host "✓ Inserted tenant: HealthCorp Medical Systems" -ForegroundColor Green

# Cleanup temp files
Remove-Item $tempFile1, $tempFile2, $tempFile3, $tempFile4, $tempFile5 -ErrorAction SilentlyContinue

Write-Host "`nData insertion completed successfully!" -ForegroundColor Green
Write-Host "Portal URL: https://ca-stamps-portal.lemonforest-88e81141.westus2.azurecontainerapps.io" -ForegroundColor Cyan
Write-Host "`nThe management portal should now display:" -ForegroundColor Yellow
Write-Host "- 2 Cells (East US and West US)" -ForegroundColor White
Write-Host "- 2 Tenants (Tech Startup Inc and HealthCorp Medical)" -ForegroundColor White
Write-Host "- 1 Operation (Tenant Creation)" -ForegroundColor White
