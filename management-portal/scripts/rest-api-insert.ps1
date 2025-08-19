# Cosmos DB data insertion using REST API
Write-Host "Starting Cosmos DB data insertion using REST API..." -ForegroundColor Green

# Get access token
try {
    $tokenResponse = az account get-access-token --resource https://cosmos.azure.com/ | ConvertFrom-Json
    $accessToken = $tokenResponse.accessToken
    Write-Host "✓ Got access token" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to get access token" -ForegroundColor Red
    exit 1
}

$cosmosAccount = "cosmos-xgjwtecm3g5pi"
$databaseName = "stamps-control-plane"
$baseUri = "https://$cosmosAccount.documents.azure.com"

# Function to insert document
function Insert-Document {
    param(
        [string]$containerName,
        [hashtable]$document
    )
    
    $uri = "$baseUri/dbs/$databaseName/colls/$containerName/docs"
    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type" = "application/json"
        "x-ms-version" = "2020-07-15"
        "x-ms-documentdb-partitionkey" = "[`"$($document.id)`"]"
    }
    
    $body = $document | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body $body
        Write-Host "✓ Inserted document: $($document.id)" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "✗ Failed to insert $($document.id): $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

Write-Host "`nInserting sample data..." -ForegroundColor Yellow

# Insert cell
$cell1 = @{
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

Insert-Document -containerName "cells" -document $cell1

# Insert tenant
$tenant1 = @{
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

Insert-Document -containerName "tenants" -document $tenant1

# Insert operation
$operation1 = @{
    id = "op-001"
    operationId = "op-001"
    operationType = "TenantCreation"
    status = "Completed"
    tenantId = "tenant-techstartup"
    cellId = "cell-eastus-01"
    startTime = (Get-Date).AddDays(-15).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    endTime = (Get-Date).AddDays(-15).AddMinutes(5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    message = "Successfully created tenant techstartup in East US Cell 01"
}

Insert-Document -containerName "operations" -document $operation1

# Insert second cell
$cell2 = @{
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
}

Insert-Document -containerName "cells" -document $cell2

# Insert second tenant
$tenant2 = @{
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
}

Insert-Document -containerName "tenants" -document $tenant2

Write-Host "`nData insertion completed!" -ForegroundColor Green
Write-Host "Portal URL: https://ca-stamps-portal.lemonforest-88e81141.westus2.azurecontainerapps.io" -ForegroundColor Cyan
Write-Host "`nRefresh your management portal to see the new data!" -ForegroundColor Yellow
