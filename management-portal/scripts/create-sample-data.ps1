# Simple data seeding script using PowerShell and Cosmos DB REST API
param(
    [string]$ResourceGroupName = "rg-stamps-mgmt",
    [string]$CosmosAccountName = "cosmos-xgjwtecm3g5pi",
    [string]$DatabaseName = "stamps-control-plane"
)

Write-Host "Creating sample data for Stamps Pattern demo..."

# First, let me create some sample cells
$sampleCells = @(
    @{
        id = "cell-001"
        cellId = "cell-001"
        cellName = "West US Shared Cell 1"
        cellType = "Shared"
        region = "westus2"
        backendPool = "westus-shared-001-backend"
        maxTenantCount = 100
        currentTenantCount = 3
        status = "Active"
        complianceFeatures = @("SOC2-Type2", "ISO27001")
        createdDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        cpuUtilization = 45.2
        memoryUtilization = 38.7
        storageUtilization = 22.1
        networkUtilization = 15.8
        skuTier = "Standard"
        monthlyCostEstimate = 1200.00
        billingModel = "Shared"
        availabilityTarget = 99.9
        autoScalingEnabled = $true
    },
    @{
        id = "cell-002"
        cellId = "cell-002"
        cellName = "East US Enterprise Cell 1"
        cellType = "Dedicated"
        region = "eastus"
        backendPool = "eastus-dedicated-001-backend"
        maxTenantCount = 1
        currentTenantCount = 1
        status = "Active"
        complianceFeatures = @("HIPAA", "SOX", "PCI-DSS", "SOC2-Type2")
        createdDate = (Get-Date).AddDays(-15).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        cpuUtilization = 25.8
        memoryUtilization = 41.2
        storageUtilization = 18.5
        networkUtilization = 12.3
        skuTier = "Premium"
        monthlyCostEstimate = 3200.00
        billingModel = "Dedicated"
        availabilityTarget = 99.99
        autoScalingEnabled = $true
    },
    @{
        id = "cell-003"
        cellId = "cell-003"
        cellName = "West US Shared Cell 2"
        cellType = "Shared"
        region = "westus2"
        backendPool = "westus-shared-002-backend"
        maxTenantCount = 100
        currentTenantCount = 1
        status = "Active"
        complianceFeatures = @("SOC2-Type2")
        createdDate = (Get-Date).AddDays(-10).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        cpuUtilization = 12.4
        memoryUtilization = 15.2
        storageUtilization = 8.7
        networkUtilization = 5.1
        skuTier = "Standard"
        monthlyCostEstimate = 1200.00
        billingModel = "Shared"
        availabilityTarget = 99.9
        autoScalingEnabled = $true
    }
)

# Sample tenants
$sampleTenants = @(
    @{
        id = "tenant-001"
        tenantId = "tenant-001"
        subdomain = "acme-corp"
        cellBackendPool = "westus-shared-001-backend"
        cellName = "West US Shared Cell 1"
        tenantTier = "SMB"
        region = "westus2"
        complianceRequirements = @("SOC2-Type2")
        status = "Active"
        createdDate = (Get-Date).AddDays(-25).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        lastModifiedDate = (Get-Date).AddDays(-2).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        estimatedMonthlyApiCalls = 50000
        contactEmail = "admin@acme-corp.com"
        organizationName = "ACME Corporation"
        businessSegment = "Small-Medium Business"
        dataResidencyRequirements = @("US")
        slaLevel = "Standard"
    },
    @{
        id = "tenant-002"
        tenantId = "tenant-002"
        subdomain = "healthtech-solutions"
        cellBackendPool = "eastus-dedicated-001-backend"
        cellName = "East US Enterprise Cell 1"
        tenantTier = "Enterprise"
        region = "eastus"
        complianceRequirements = @("HIPAA", "SOC2-Type2")
        status = "Active"
        createdDate = (Get-Date).AddDays(-12).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        estimatedMonthlyApiCalls = 500000
        contactEmail = "security@healthtech.com"
        organizationName = "HealthTech Solutions Inc."
        businessSegment = "Healthcare"
        dataResidencyRequirements = @("US")
        slaLevel = "Enterprise"
    },
    @{
        id = "tenant-003"
        tenantId = "tenant-003"
        subdomain = "startup-innovate"
        cellBackendPool = "westus-shared-001-backend"
        cellName = "West US Shared Cell 1"
        tenantTier = "Startup"
        region = "westus2"
        complianceRequirements = @()
        status = "Active"
        createdDate = (Get-Date).AddDays(-5).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        estimatedMonthlyApiCalls = 10000
        contactEmail = "founders@startup-innovate.com"
        organizationName = "Innovate Startup LLC"
        businessSegment = "Startup"
        dataResidencyRequirements = @("US")
        slaLevel = "Basic"
    },
    @{
        id = "tenant-004"
        tenantId = "tenant-004"
        subdomain = "global-logistics"
        cellBackendPool = "westus-shared-002-backend"
        cellName = "West US Shared Cell 2"
        tenantTier = "Shared"
        region = "westus2"
        complianceRequirements = @("SOC2-Type2")
        status = "Active"
        createdDate = (Get-Date).AddDays(-8).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        estimatedMonthlyApiCalls = 75000
        contactEmail = "it@global-logistics.com"
        organizationName = "Global Logistics Corp"
        businessSegment = "Enterprise"
        dataResidencyRequirements = @("US")
        slaLevel = "Standard"
    }
)

# Sample operations
$sampleOperations = @(
    @{
        id = "op-001"
        type = "deployment"
        status = "completed"
        tenantId = "tenant-001"
        cellId = "cell-001"
        description = "Initial tenant deployment for ACME Corporation"
        startedAt = (Get-Date).AddDays(-25).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        completedAt = (Get-Date).AddDays(-25).AddHours(2).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    },
    @{
        id = "op-002"
        type = "scaling"
        status = "completed"
        tenantId = "tenant-002"
        cellId = "cell-002"
        description = "Scale up resources for HealthTech Solutions enterprise workload"
        startedAt = (Get-Date).AddDays(-10).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        completedAt = (Get-Date).AddDays(-10).AddMinutes(45).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    },
    @{
        id = "op-003"
        type = "migration"
        status = "in-progress"
        tenantId = "tenant-001"
        cellId = "cell-001"
        description = "Migrate ACME Corp data to new storage tier"
        startedAt = (Get-Date).AddHours(-2).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        completedAt = $null
    },
    @{
        id = "op-004"
        type = "deployment"
        status = "completed"
        tenantId = "tenant-003"
        cellId = "cell-001"
        description = "Onboard Innovate Startup to shared cell"
        startedAt = (Get-Date).AddDays(-5).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        completedAt = (Get-Date).AddDays(-5).AddMinutes(15).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    },
    @{
        id = "op-005"
        type = "maintenance"
        status = "scheduled"
        tenantId = $null
        cellId = "cell-003"
        description = "Scheduled maintenance window for West US Shared Cell 2"
        startedAt = (Get-Date).AddDays(2).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        completedAt = $null
    }
)

Write-Host "Sample data created. Use these with the management portal or Functions to populate Cosmos DB."
Write-Host "Cells: $($sampleCells.Count)"
Write-Host "Tenants: $($sampleTenants.Count)"  
Write-Host "Operations: $($sampleOperations.Count)"

# Output the data as JSON for easy consumption
$sampleData = @{
    cells = $sampleCells
    tenants = $sampleTenants
    operations = $sampleOperations
}

$sampleData | ConvertTo-Json -Depth 10 | Out-File -FilePath "sample-data.json" -Encoding UTF8
Write-Host "Sample data saved to sample-data.json"
