# Populate Cosmos DB with sample data using Azure Functions API
Write-Host "Starting data population using Functions API..." -ForegroundColor Green

$baseUrl = "http://localhost:7071/api"
$headers = @{ "Content-Type" = "application/json" }

# Test health first
try {
    $health = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get
    Write-Host "✓ Functions are healthy" -ForegroundColor Green
} catch {
    Write-Host "✗ Functions are not responding. Please ensure Azure Functions are running on port 7071" -ForegroundColor Red
    exit 1
}

# First, let's provision some cells
Write-Host "`nProvisioning cells..." -ForegroundColor Yellow

$cells = @(
    @{
        region = "East US"
        cellType = "Standard"
        estimatedCapacity = 1000
        complianceFeatures = @("SOC2", "GDPR")
        reason = "Initial deployment for startup and SMB tenants"
    },
    @{
        region = "West US"
        cellType = "High Performance"
        estimatedCapacity = 2000
        complianceFeatures = @("SOC2", "HIPAA", "FedRAMP")
        reason = "High-performance cell for enterprise workloads"
    },
    @{
        region = "Central US"
        cellType = "Standard"
        estimatedCapacity = 1500
        complianceFeatures = @("SOC2", "PCI-DSS")
        reason = "Standard capacity cell for general workloads"
    }
)

$provisionedCells = @()
foreach ($cell in $cells) {
    try {
        $cellData = $cell | ConvertTo-Json -Depth 10
        $result = Invoke-RestMethod -Uri "$baseUrl/cells/provision" -Method Post -Body $cellData -Headers $headers
        $provisionedCells += $result
        Write-Host "✓ Provisioned cell: $($result.cellName) in $($cell.region)" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to provision cell in $($cell.region): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Start-Sleep -Seconds 2

# Now create tenants
Write-Host "`nCreating tenants..." -ForegroundColor Yellow

$tenants = @(
    @{
        subdomain = "techstartup"
        contactEmail = "admin@techstartup.com"
        organizationName = "Tech Startup Inc"
        businessSegment = "SaaS Technology"
        tenantTier = "Startup"
        complianceRequirements = @("SOC2")
        dataResidencyRequirements = @("United States")
        performanceRequirements = @{
            maxLatency = "100ms"
            throughputTarget = "1000rps"
            availabilityTarget = "99.9%"
        }
    },
    @{
        subdomain = "healthcorp"
        contactEmail = "admin@healthcorp.com"
        organizationName = "HealthCorp Medical Systems"
        businessSegment = "Healthcare"
        tenantTier = "Enterprise"
        complianceRequirements = @("HIPAA", "SOC2")
        dataResidencyRequirements = @("United States")
        performanceRequirements = @{
            maxLatency = "50ms"
            throughputTarget = "5000rps"
            availabilityTarget = "99.99%"
        }
    },
    @{
        subdomain = "retailplus"
        contactEmail = "admin@retailplus.com"
        organizationName = "Retail Plus Solutions"
        businessSegment = "E-commerce"
        tenantTier = "SMB"
        complianceRequirements = @("PCI-DSS", "SOC2")
        dataResidencyRequirements = @("United States")
        performanceRequirements = @{
            maxLatency = "75ms"
            throughputTarget = "2500rps"
            availabilityTarget = "99.95%"
        }
    },
    @{
        subdomain = "financefast"
        contactEmail = "admin@financefast.com"
        organizationName = "Finance Fast LLC"
        businessSegment = "Financial Services"
        tenantTier = "Enterprise"
        complianceRequirements = @("SOC2", "FedRAMP")
        dataResidencyRequirements = @("United States")
        performanceRequirements = @{
            maxLatency = "25ms"
            throughputTarget = "10000rps"
            availabilityTarget = "99.99%"
        }
    }
)

$createdTenants = @()
foreach ($tenant in $tenants) {
    try {
        $tenantData = $tenant | ConvertTo-Json -Depth 10
        $result = Invoke-RestMethod -Uri "$baseUrl/tenant" -Method Post -Body $tenantData -Headers $headers
        $createdTenants += $result
        Write-Host "✓ Created tenant: $($tenant.subdomain) ($($tenant.organizationName))" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to create tenant $($tenant.subdomain): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Start-Sleep -Seconds 2

# Check cell analytics
Write-Host "`nChecking cell analytics..." -ForegroundColor Yellow
try {
    $analytics = Invoke-RestMethod -Uri "$baseUrl/cells/analytics" -Method Get
    Write-Host "✓ Cell analytics retrieved successfully" -ForegroundColor Green
    Write-Host "   Total Cells: $($analytics.totalCells)" -ForegroundColor Cyan
    Write-Host "   Total Tenants: $($analytics.totalTenants)" -ForegroundColor Cyan
    Write-Host "   Average Utilization: $($analytics.averageUtilization)%" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Failed to get cell analytics: $($_.Exception.Message)" -ForegroundColor Red
}

# Check capacity
Write-Host "`nChecking cell capacity..." -ForegroundColor Yellow
try {
    $capacity = Invoke-RestMethod -Uri "$baseUrl/cells/capacity" -Method Get
    Write-Host "✓ Cell capacity retrieved successfully" -ForegroundColor Green
    foreach ($cell in $capacity.cells) {
        Write-Host "   $($cell.cellName): $($cell.currentTenants)/$($cell.maxCapacity) tenants ($([math]::Round($cell.utilizationPercentage, 1))% utilized)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "✗ Failed to get cell capacity: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nData population completed!" -ForegroundColor Green
Write-Host "You can now refresh the management portal to see the data." -ForegroundColor Yellow
Write-Host "Portal URL: https://ca-stamps-portal.lemonforest-88e81141.westus2.azurecontainerapps.io" -ForegroundColor Cyan
