# Insert data using REST API calls to Cosmos DB
Write-Host "Starting Cosmos DB data insertion using REST API..." -ForegroundColor Green

$resourceGroup = "rg-stamps-mgmt"
$cosmosAccount = "cosmos-xgjwtecm3g5pi"
$databaseName = "stamps-control-plane"

# Get access token
Write-Host "Getting access token..." -ForegroundColor Yellow
$accessToken = az account get-access-token --resource "https://cosmos.azure.com/" --query "accessToken" -o tsv

if (-not $accessToken) {
    Write-Host "✗ Failed to get access token" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Got access token" -ForegroundColor Green

# Get Cosmos DB endpoint
$cosmosEndpoint = az cosmosdb show -g $resourceGroup -n $cosmosAccount --query "documentEndpoint" -o tsv
Write-Host "✓ Cosmos endpoint: $cosmosEndpoint" -ForegroundColor Green

# Function to insert document using REST API
function Insert-CosmosDocument {
    param(
        [string]$ContainerName,
        [hashtable]$Document,
        [string]$CosmosEndpoint,
        [string]$AccessToken,
        [string]$DatabaseName
    )
    
    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
        "x-ms-version" = "2020-07-15"
        "x-ms-documentdb-partitionkey" = '["' + $Document.id + '"]'
    }
    
    $uri = "$CosmosEndpoint/dbs/$DatabaseName/colls/$ContainerName/docs"
    $body = $Document | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body $body
        return $true
    } catch {
        Write-Host "Error inserting document: $_" -ForegroundColor Red
        return $false
    }
}

# Insert sample cell
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
}

if (Insert-CosmosDocument -ContainerName "cells" -Document $cellDoc -CosmosEndpoint $cosmosEndpoint -AccessToken $accessToken -DatabaseName $databaseName) {
    Write-Host "✓ Inserted cell: East US Cell 01" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to insert cell" -ForegroundColor Red
}

# Insert sample tenant
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
}

if (Insert-CosmosDocument -ContainerName "tenants" -Document $tenantDoc -CosmosEndpoint $cosmosEndpoint -AccessToken $accessToken -DatabaseName $databaseName) {
    Write-Host "✓ Inserted tenant: Tech Startup Inc" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to insert tenant" -ForegroundColor Red
}

# Insert sample operation
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
}

if (Insert-CosmosDocument -ContainerName "operations" -Document $operationDoc -CosmosEndpoint $cosmosEndpoint -AccessToken $accessToken -DatabaseName $databaseName) {
    Write-Host "✓ Inserted operation: TenantCreation" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to insert operation" -ForegroundColor Red
}

Write-Host "`nData insertion using REST API completed!" -ForegroundColor Green
