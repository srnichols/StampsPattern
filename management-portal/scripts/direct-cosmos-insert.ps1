# Direct Cosmos DB data population script
# This script directly inserts sample data into Cosmos DB using the .NET SDK

Add-Type -AssemblyName System.Web

Write-Host "Starting direct Cosmos DB data population..." -ForegroundColor Green

# Connection configuration - using production Cosmos DB
$cosmosAccountName = "cosmos-xgjwtecm3g5pi"
$databaseName = "stamps-control-plane"
$cosmosEndpoint = "https://$cosmosAccountName.documents.azure.com:443/"

Write-Host "Target Cosmos DB: $cosmosEndpoint" -ForegroundColor Cyan
Write-Host "Database: $databaseName" -ForegroundColor Cyan

# Create PowerShell script to insert data using Azure CLI (since we have Azure CLI available)
$insertScript = @'
# Get Cosmos DB connection string
Write-Host "Getting Cosmos DB connection string..." -ForegroundColor Yellow
$connectionString = az cosmosdb keys list --name cosmos-xgjwtecm3g5pi --resource-group rg-stamps-mgmt --type connection-strings --query "connectionStrings[0].connectionString" --output tsv

if (-not $connectionString) {
    Write-Host "Failed to get connection string. Make sure you're logged in to Azure CLI." -ForegroundColor Red
    exit 1
}

Write-Host "✓ Got connection string" -ForegroundColor Green

# Sample data
$cells = @(
    @{
        id = "cell-eastus-01"
        cellId = "cell-eastus-01"
        cellName = "East US Cell 01"
        region = "eastus"
        backendPool = "eastus-pool-01.stamps.com"
        maxCapacity = 1000
        currentTenants = 0
        isActive = $true
        cellType = "Standard"
        complianceFeatures = @("SOC2", "GDPR")
        healthStatus = "Healthy"
        lastHealthCheck = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        deploymentDate = [DateTime]::UtcNow.AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ssZ")
        maintenanceWindow = "02:00-04:00 UTC"
    },
    @{
        id = "cell-westus-01"
        cellId = "cell-westus-01"
        cellName = "West US Cell 01"
        region = "westus"
        backendPool = "westus-pool-01.stamps.com"
        maxCapacity = 2000
        currentTenants = 0
        isActive = $true
        cellType = "High Performance"
        complianceFeatures = @("SOC2", "HIPAA", "FedRAMP")
        healthStatus = "Healthy"
        lastHealthCheck = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        deploymentDate = [DateTime]::UtcNow.AddDays(-45).ToString("yyyy-MM-ddTHH:mm:ssZ")
        maintenanceWindow = "03:00-05:00 UTC"
    },
    @{
        id = "cell-centralus-01"
        cellId = "cell-centralus-01"
        cellName = "Central US Cell 01"
        region = "centralus"
        backendPool = "centralus-pool-01.stamps.com"
        maxCapacity = 1500
        currentTenants = 0
        isActive = $true
        cellType = "Standard"
        complianceFeatures = @("SOC2", "PCI-DSS")
        healthStatus = "Healthy"
        lastHealthCheck = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        deploymentDate = [DateTime]::UtcNow.AddDays(-60).ToString("yyyy-MM-ddTHH:mm:ssZ")
        maintenanceWindow = "01:00-03:00 UTC"
    }
)

$tenants = @(
    @{
        id = "tenant-techstartup"
        tenantId = "tenant-techstartup"
        subdomain = "techstartup"
        cellBackendPool = "eastus-pool-01.stamps.com"
        cellName = "East US Cell 01"
        region = "eastus"
        tenantTier = "Startup"
        isActive = $true
        createdDate = [DateTime]::UtcNow.AddDays(-15).ToString("yyyy-MM-ddTHH:mm:ssZ")
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
    },
    @{
        id = "tenant-healthcorp"
        tenantId = "tenant-healthcorp"
        subdomain = "healthcorp"
        cellBackendPool = "westus-pool-01.stamps.com"
        cellName = "West US Cell 01"
        region = "westus"
        tenantTier = "Enterprise"
        isActive = $true
        createdDate = [DateTime]::UtcNow.AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ssZ")
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
    },
    @{
        id = "tenant-retailplus"
        tenantId = "tenant-retailplus"
        subdomain = "retailplus"
        cellBackendPool = "centralus-pool-01.stamps.com"
        cellName = "Central US Cell 01"
        region = "centralus"
        tenantTier = "SMB"
        isActive = $true
        createdDate = [DateTime]::UtcNow.AddDays(-20).ToString("yyyy-MM-ddTHH:mm:ssZ")
        contactEmail = "admin@retailplus.com"
        organizationName = "Retail Plus Solutions"
        businessSegment = "E-commerce"
        complianceRequirements = @("PCI-DSS", "SOC2")
        dataResidencyRequirements = @("United States")
        performanceRequirements = @{
            maxLatency = "75ms"
            throughputTarget = "2500rps"
            availabilityTarget = "99.95%"
        }
    },
    @{
        id = "tenant-financefast"
        tenantId = "tenant-financefast"
        subdomain = "financefast"
        cellBackendPool = "westus-pool-01.stamps.com"
        cellName = "West US Cell 01"
        region = "westus"
        tenantTier = "Enterprise"
        isActive = $true
        createdDate = [DateTime]::UtcNow.AddDays(-10).ToString("yyyy-MM-ddTHH:mm:ssZ")
        contactEmail = "admin@financefast.com"
        organizationName = "Finance Fast LLC"
        businessSegment = "Financial Services"
        complianceRequirements = @("SOC2", "FedRAMP")
        dataResidencyRequirements = @("United States")
        performanceRequirements = @{
            maxLatency = "25ms"
            throughputTarget = "10000rps"
            availabilityTarget = "99.99%"
        }
    }
)

$operations = @(
    @{
        id = "op-001"
        operationId = "op-001"
        operationType = "TenantCreation"
        status = "Completed"
        tenantId = "tenant-techstartup"
        cellId = "cell-eastus-01"
        startTime = [DateTime]::UtcNow.AddDays(-15).ToString("yyyy-MM-ddTHH:mm:ssZ")
        endTime = [DateTime]::UtcNow.AddDays(-15).AddMinutes(5).ToString("yyyy-MM-ddTHH:mm:ssZ")
        message = "Successfully created tenant techstartup in East US Cell 01"
    },
    @{
        id = "op-002"
        operationId = "op-002"
        operationType = "CellProvisioning"
        status = "Completed"
        cellId = "cell-westus-01"
        startTime = [DateTime]::UtcNow.AddDays(-45).ToString("yyyy-MM-ddTHH:mm:ssZ")
        endTime = [DateTime]::UtcNow.AddDays(-45).AddMinutes(20).ToString("yyyy-MM-ddTHH:mm:ssZ")
        message = "Successfully provisioned West US Cell 01 with high-performance configuration"
    },
    @{
        id = "op-003"
        operationId = "op-003"
        operationType = "TenantMigration"
        status = "InProgress"
        tenantId = "tenant-retailplus"
        cellId = "cell-centralus-01"
        startTime = [DateTime]::UtcNow.AddMinutes(-30).ToString("yyyy-MM-ddTHH:mm:ssZ")
        message = "Migrating tenant retailplus to optimized cell configuration"
    },
    @{
        id = "op-004"
        operationId = "op-004"
        operationType = "CapacityMonitoring"
        status = "Completed"
        cellId = "cell-eastus-01"
        startTime = [DateTime]::UtcNow.AddHours(-1).ToString("yyyy-MM-ddTHH:mm:ssZ")
        endTime = [DateTime]::UtcNow.AddHours(-1).AddMinutes(2).ToString("yyyy-MM-ddTHH:mm:ssZ")
        message = "Capacity monitoring completed for East US Cell 01 - 65% utilization"
    },
    @{
        id = "op-005"
        operationId = "op-005"
        operationType = "TenantCreation"
        status = "Failed"
        tenantId = "tenant-failed-001"
        cellId = "cell-westus-01"
        startTime = [DateTime]::UtcNow.AddHours(-2).ToString("yyyy-MM-ddTHH:mm:ssZ")
        endTime = [DateTime]::UtcNow.AddHours(-2).AddMinutes(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
        message = "Failed to create tenant due to insufficient capacity"
        errorMessage = "Cell capacity exceeded: 95% utilization detected"
    }
)

# Function to insert documents using Azure CLI
function Insert-CosmosDocuments {
    param($containerName, $documents, $description)
    
    Write-Host "Inserting $description..." -ForegroundColor Yellow
    
    foreach ($doc in $documents) {
        $docJson = $doc | ConvertTo-Json -Depth 10 -Compress
        $tempFile = [System.IO.Path]::GetTempFileName()
        $docJson | Out-File -FilePath $tempFile -Encoding utf8
        
        try {
            $result = az cosmosdb sql container create --name $containerName --resource-group rg-stamps-mgmt --account-name cosmos-xgjwtecm3g5pi --database-name stamps-control-plane --partition-key-path "/id" 2>$null
            
            az cosmosdb sql item create --resource-group rg-stamps-mgmt --account-name cosmos-xgjwtecm3g5pi --database-name stamps-control-plane --container-name $containerName --body "@$tempFile"
            Write-Host "✓ Inserted: $($doc.id)" -ForegroundColor Green
        } catch {
            Write-Host "✗ Failed to insert $($doc.id): $($_.Exception.Message)" -ForegroundColor Red
        } finally {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        }
    }
}

# Insert data
Insert-CosmosDocuments "cells" $cells "Cell information"
Insert-CosmosDocuments "tenants" $tenants "Tenant information"  
Insert-CosmosDocuments "operations" $operations "Operation logs"

Write-Host "`nData insertion completed!" -ForegroundColor Green
Write-Host "You can now refresh the management portal to see the populated data." -ForegroundColor Yellow
'@

# Write the script to a temporary file and execute it
$scriptPath = "$env:TEMP\insert-cosmos-data.ps1"
$insertScript | Out-File -FilePath $scriptPath -Encoding UTF8

Write-Host "Executing Cosmos DB insertion script..." -ForegroundColor Yellow
& PowerShell.exe -ExecutionPolicy Bypass -File $scriptPath

Remove-Item $scriptPath -ErrorAction SilentlyContinue

Write-Host "`nDirect data population completed!" -ForegroundColor Green
Write-Host "Portal URL: https://ca-stamps-portal.lemonforest-88e81141.westus2.azurecontainerapps.io" -ForegroundColor Cyan
