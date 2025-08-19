# Script to populate Cosmos DB using the Functions API
$functionsBaseUrl = "http://localhost:7071/api"

Write-Host "Populating Cosmos DB with sample data using Functions..."

# Sample cell data to create (we'll use the provision endpoint)
$sampleCells = @(
    @{
        cellName = "West US Shared Cell 1"
        cellType = "Shared"
        region = "westus2"
        maxTenantCount = 100
        complianceFeatures = @("SOC2-Type2", "ISO27001")
        skuTier = "Standard"
        autoScalingEnabled = $true
    },
    @{
        cellName = "East US Enterprise Cell 1"
        cellType = "Dedicated"
        region = "eastus"
        maxTenantCount = 1
        complianceFeatures = @("HIPAA", "SOX", "PCI-DSS", "SOC2-Type2")
        skuTier = "Premium"
        autoScalingEnabled = $true
    },
    @{
        cellName = "West US Shared Cell 2"
        cellType = "Shared"
        region = "westus2"
        maxTenantCount = 100
        complianceFeatures = @("SOC2-Type2")
        skuTier = "Standard"
        autoScalingEnabled = $true
    }
)

# Sample tenant data to create
$sampleTenants = @(
    @{
        tenantId = "tenant-001"
        subdomain = "acme-corp"
        tenantTier = "SMB"
        region = "westus2"
        complianceRequirements = @("SOC2-Type2")
        estimatedMonthlyApiCalls = 50000
        contactEmail = "admin@acme-corp.com"
        organizationName = "ACME Corporation"
        businessSegment = "Small-Medium Business"
        dataResidencyRequirements = @("US")
        slaLevel = "Standard"
    },
    @{
        tenantId = "tenant-002"
        subdomain = "healthtech-solutions"
        tenantTier = "Enterprise"
        region = "eastus"
        complianceRequirements = @("HIPAA", "SOC2-Type2")
        estimatedMonthlyApiCalls = 500000
        contactEmail = "security@healthtech.com"
        organizationName = "HealthTech Solutions Inc."
        businessSegment = "Healthcare"
        dataResidencyRequirements = @("US")
        slaLevel = "Enterprise"
    },
    @{
        tenantId = "tenant-003"
        subdomain = "startup-innovate"
        tenantTier = "Startup"
        region = "westus2"
        complianceRequirements = @()
        estimatedMonthlyApiCalls = 10000
        contactEmail = "founders@startup-innovate.com"
        organizationName = "Innovate Startup LLC"
        businessSegment = "Startup"
        dataResidencyRequirements = @("US")
        slaLevel = "Basic"
    },
    @{
        tenantId = "tenant-004"
        subdomain = "global-logistics"
        tenantTier = "Shared"
        region = "westus2"
        complianceRequirements = @("SOC2-Type2")
        estimatedMonthlyApiCalls = 75000
        contactEmail = "it@global-logistics.com"
        organizationName = "Global Logistics Corp"
        businessSegment = "Enterprise"
        dataResidencyRequirements = @("US")
        slaLevel = "Standard"
    }
)

# Function to call the Functions API
function Invoke-FunctionApi {
    param(
        [string]$Endpoint,
        [string]$Method = "POST",
        [object]$Body = $null
    )
    
    try {
        $headers = @{ "Content-Type" = "application/json" }
        $url = "$functionsBaseUrl$Endpoint"
        
        if ($Body) {
            $jsonBody = $Body | ConvertTo-Json -Depth 10
            $response = Invoke-RestMethod -Uri $url -Method $Method -Body $jsonBody -Headers $headers
        } else {
            $response = Invoke-RestMethod -Uri $url -Method $Method -Headers $headers
        }
        
        return $response
    }
    catch {
        Write-Warning "Failed to call $url`: $_"
        return $null
    }
}

# Check if Functions are running
try {
    Write-Host "Testing Functions API connectivity..."
    $healthCheck = Invoke-FunctionApi -Endpoint "/health" -Method "GET"
    if ($healthCheck) {
        Write-Host "✅ Functions API is running" -ForegroundColor Green
    } else {
        Write-Host "❌ Functions API health check failed" -ForegroundColor Red
        return
    }
}
catch {
    Write-Host "❌ Could not connect to Functions API. Make sure it's running on $functionsBaseUrl" -ForegroundColor Red
    return
}

# Create cells first (provision them)
Write-Host "`nCreating cells..."
foreach ($cell in $sampleCells) {
    Write-Host "Creating cell: $($cell.cellName)"
    $result = Invoke-FunctionApi -Endpoint "/cells/provision" -Method "POST" -Body $cell
    if ($result) {
        Write-Host "✅ Created cell: $($cell.cellName)" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to create cell: $($cell.cellName)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}

# Create tenants
Write-Host "`nCreating tenants..."
foreach ($tenant in $sampleTenants) {
    Write-Host "Creating tenant: $($tenant.organizationName) ($($tenant.subdomain))"
    $result = Invoke-FunctionApi -Endpoint "/tenant" -Method "POST" -Body $tenant
    if ($result) {
        Write-Host "✅ Created tenant: $($tenant.organizationName)" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to create tenant: $($tenant.organizationName)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}

Write-Host "`n🎉 Sample data creation completed!" -ForegroundColor Green
Write-Host "Check the Cosmos DB and management portal dashboard for the new data."
