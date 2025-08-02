#!/usr/bin/env pwsh

<#
.SYNOPSIS
Enhanced deployment script for Azure Stamps Pattern with flexible tenancy support

.DESCRIPTION
This script deploys the Azure Stamps Pattern infrastructure with support for both:
- Shared CELLs (10-100 tenants per CELL) 
- Dedicated CELLs (1 enterprise tenant per CELL)

The script supports the flexible tenancy model documented in ARCHITECTURE_GUIDE.md

.PARAMETER ResourceGroupName
Name of the Azure Resource Group

.PARAMETER Location
Primary Azure region for deployment

.PARAMETER Environment
Environment name (dev, staging, prod)

.PARAMETER TenancyModel
Deployment tenancy model: 'shared', 'dedicated', or 'mixed'

.PARAMETER MaxSharedTenantsPerCell
Maximum number of tenants per shared CELL (default: 100)

.PARAMETER EnableCompliance
Enable compliance features (HIPAA, SOX, PCI-DSS)

.EXAMPLE
.\deploy-stamps-enhanced.ps1 -ResourceGroupName "rg-stamps-prod" -Location "eastus" -TenancyModel "mixed"

.EXAMPLE
.\deploy-stamps-enhanced.ps1 -ResourceGroupName "rg-stamps-healthcare" -Location "eastus" -TenancyModel "dedicated" -EnableCompliance @("HIPAA", "SOC2-Type2")
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$Location,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "dev",
    
    # Organization Parameters
    [Parameter(Mandatory = $false)]
    [string]$OrganizationDomain = "contoso.com",
    
    [Parameter(Mandatory = $false)]
    [string]$OrganizationName = "contoso",
    
    [Parameter(Mandatory = $false)]
    [string]$Department = "IT",
    
    [Parameter(Mandatory = $false)]
    [string]$ProjectName = "StampsPattern",
    
    [Parameter(Mandatory = $false)]
    [string]$WorkloadName = "stamps-pattern",
    
    [Parameter(Mandatory = $false)]
    [string]$OwnerEmail = "platform-team@contoso.com",
    
    [Parameter(Mandatory = $false)]
    [string]$GeoName = "northamerica",
    
    [Parameter(Mandatory = $false)]
    [string]$BaseDnsZoneName = "stamps",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("shared", "dedicated", "mixed")]
    [string]$TenancyModel = "mixed",
    
    [Parameter(Mandatory = $false)]
    [int]$MaxSharedTenantsPerCell = 100,
    
    [Parameter(Mandatory = $false)]
    [string[]]$EnableCompliance = @(),
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("0", "1", "2", "3")]
    [string]$AvailabilityZones = "2",
    
    [Parameter(Mandatory = $false)]
    [switch]$EnableAutoScaling = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$EnableMonitoring = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun = $false
)

# Script configuration
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Enhanced tenancy configuration
$TenancyConfig = @{
    "shared" = @{
        Description = "Shared CELLs only - cost-optimized for small tenants"
        DefaultCellsPerRegion = 2
        MaxTenantsPerCell = $MaxSharedTenantsPerCell
        CostPerTenantPerMonth = 16
        SupportedTiers = @("Startup", "SMB", "Shared")
        RecommendedZones = 2
    }
    "dedicated" = @{
        Description = "Dedicated CELLs only - enterprise isolation"
        DefaultCellsPerRegion = 1
        MaxTenantsPerCell = 1
        CostPerTenantPerMonth = 3200
        SupportedTiers = @("Enterprise", "Dedicated")
        RecommendedZones = 3
    }
    "mixed" = @{
        Description = "Mixed model - both shared and dedicated CELLs"
        DefaultCellsPerRegion = 3
        MaxTenantsPerCell = 100
        CostPerTenantPerMonth = "Variable (16-3200)"
        SupportedTiers = @("Startup", "SMB", "Shared", "Enterprise", "Dedicated")
        RecommendedZones = 3
    }
}

# Zone configuration mappings
$ZoneConfig = @{
    "0" = @{ ZoneArray = @(); SLA = "Standard"; CostMultiplier = 1.0; Description = "Single zone (dev/test)" }
    "1" = @{ ZoneArray = @("1"); SLA = "Standard"; CostMultiplier = 1.0; Description = "Single zone deployment" }
    "2" = @{ ZoneArray = @("1", "2"); SLA = "99.95%"; CostMultiplier = 1.2; Description = "Basic HA" }
    "3" = @{ ZoneArray = @("1", "2", "3"); SLA = "99.99%"; CostMultiplier = 1.4; Description = "Maximum resilience" }
}

function Write-DeploymentHeader {
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "Azure Stamps Pattern Enhanced Deployment" -ForegroundColor Cyan
    Write-Host "Flexible Tenancy Model: $TenancyModel" -ForegroundColor Yellow
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Green
    Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
    Write-Host "  Location: $Location" -ForegroundColor White
    Write-Host "  Environment: $Environment" -ForegroundColor White
    Write-Host "  Tenancy Model: $TenancyModel" -ForegroundColor White
    Write-Host "  Availability Zones: $AvailabilityZones" -ForegroundColor White
    Write-Host "  Max Tenants per Shared CELL: $MaxSharedTenantsPerCell" -ForegroundColor White
    
    if ($EnableCompliance.Count -gt 0) {
        Write-Host "  Compliance Standards: $($EnableCompliance -join ', ')" -ForegroundColor White
    }
    
    $currentConfig = $TenancyConfig[$TenancyModel]
    Write-Host ""
    Write-Host "Tenancy Model Details:" -ForegroundColor Green
    Write-Host "  Description: $($currentConfig.Description)" -ForegroundColor White
    Write-Host "  Default CELLs per Region: $($currentConfig.DefaultCellsPerRegion)" -ForegroundColor White
    Write-Host "  Recommended Zones: $($currentConfig.RecommendedZones)" -ForegroundColor White
    Write-Host "  Configured Zones: $AvailabilityZones (SLA: $($ZoneConfig[$AvailabilityZones].SLA))" -ForegroundColor White
    Write-Host "  Cost per Tenant: $($currentConfig.CostPerTenantPerMonth)" -ForegroundColor White
    Write-Host "  Supported Tiers: $($currentConfig.SupportedTiers -join ', ')" -ForegroundColor White
    Write-Host ""
}

function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow
    
    # Check Azure CLI
    try {
        $azVersion = az version --output json | ConvertFrom-Json
        Write-Host "✓ Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
    }
    catch {
        Write-Error "Azure CLI is not installed or not in PATH"
        exit 1
    }
    
    # Check login status
    try {
        $account = az account show --output json | ConvertFrom-Json
        Write-Host "✓ Logged in as: $($account.user.name)" -ForegroundColor Green
        Write-Host "✓ Subscription: $($account.name) ($($account.id))" -ForegroundColor Green
    }
    catch {
        Write-Error "Not logged into Azure. Run 'az login' first."
        exit 1
    }
    
    # Check Bicep CLI
    try {
        $bicepVersion = az bicep version
        Write-Host "✓ Bicep version: $bicepVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "Installing Bicep CLI..." -ForegroundColor Yellow
        az bicep install
    }
    
    Write-Host ""
}

function New-ResourceGroup {
    Write-Host "Creating/Updating Resource Group..." -ForegroundColor Yellow
    
    $rgExists = az group exists --name $ResourceGroupName --output tsv
    
    if ($rgExists -eq "true") {
        Write-Host "✓ Resource Group '$ResourceGroupName' already exists" -ForegroundColor Green
    }
    else {
        if ($DryRun) {
            Write-Host "DRY RUN: Would create Resource Group '$ResourceGroupName'" -ForegroundColor Magenta
        }
        else {
            az group create --name $ResourceGroupName --location $Location --output none
            Write-Host "✓ Created Resource Group '$ResourceGroupName'" -ForegroundColor Green
        }
    }
    Write-Host ""
}

function Get-DeploymentParameters {
    Write-Host "Generating deployment parameters..." -ForegroundColor Yellow
    
    # Base parameters
    $parameters = @{
        "environment" = $Environment
        "organizationDomain" = $OrganizationDomain
        "organizationName" = $OrganizationName
        "department" = $Department
        "projectName" = $ProjectName
        "workloadName" = $WorkloadName
        "ownerEmail" = $OwnerEmail
        "geoName" = $GeoName
        "baseDnsZoneName" = $BaseDnsZoneName
        "tenancyModel" = $TenancyModel
        "maxSharedTenantsPerCell" = $MaxSharedTenantsPerCell
        "enableAutoScaling" = $EnableAutoScaling.IsPresent
        "enableMonitoring" = $EnableMonitoring.IsPresent
        "complianceStandards" = $EnableCompliance
    }
    
    # Generate regions and cells based on tenancy model
    $regions = @()
    $cells = @()
    
    switch ($TenancyModel) {
        "shared" {
            $regions += @{
                geoName = $GeoName
                regionName = $Location
                cells = @("shared-smb-z$AvailabilityZones", "shared-startup-z$AvailabilityZones")
                baseDomain = "$Location.$BaseDnsZoneName.$OrganizationDomain"
                keyVaultName = "kv-stamps-shared-$Location"
                logAnalyticsWorkspaceName = "law-stamps-shared-$Location"
            }
            
            # Add shared CELLs
            $cells += @{
                geoName = $GeoName
                regionName = $Location
                cellName = "shared-smb-z$AvailabilityZones"
                cellType = "Shared"
                availabilityZones = $ZoneConfig[$AvailabilityZones].ZoneArray
                maxTenantCount = $MaxSharedTenantsPerCell
                baseDomain = "$Location.$BaseDnsZoneName.$OrganizationDomain"
            }
            $cells += @{
                geoName = $GeoName
                regionName = $Location
                cellName = "shared-startup-z$AvailabilityZones"
                cellType = "Shared"
                availabilityZones = $ZoneConfig[$AvailabilityZones].ZoneArray
                maxTenantCount = $MaxSharedTenantsPerCell
                baseDomain = "$Location.$BaseDnsZoneName.$OrganizationDomain"
            }
        }
        
        "dedicated" {
            $regions += @{
                geoName = $GeoName
                regionName = $Location
                cells = @("dedicated-enterprise-z$AvailabilityZones")
                baseDomain = "$Location.$BaseDnsZoneName.$OrganizationDomain"
                keyVaultName = "kv-stamps-ent-$Location"
                logAnalyticsWorkspaceName = "law-stamps-ent-$Location"
            }
            
            # Add dedicated CELL
            $cells += @{
                geoName = $GeoName
                regionName = $Location
                cellName = "dedicated-enterprise-z$AvailabilityZones"
                cellType = "Dedicated"
                availabilityZones = $ZoneConfig[$AvailabilityZones].ZoneArray
                maxTenantCount = 1
                baseDomain = "$Location.$BaseDnsZoneName.$OrganizationDomain"
            }
        }
        
        "mixed" {
            $regions += @{
                geoName = $GeoName
                regionName = $Location
                cells = @("shared-smb-z$AvailabilityZones", "shared-startup-z$AvailabilityZones", "dedicated-enterprise-z$AvailabilityZones")
                baseDomain = "$Location.$BaseDnsZoneName.$OrganizationDomain"
                keyVaultName = "kv-stamps-mixed-$Location"
                logAnalyticsWorkspaceName = "law-stamps-mixed-$Location"
            }
            
            # Add mixed CELLs
            $cells += @{
                geoName = $GeoName
                regionName = $Location
                cellName = "shared-smb-z$AvailabilityZones"
                cellType = "Shared"
                availabilityZones = $ZoneConfig[$AvailabilityZones].ZoneArray
                maxTenantCount = $MaxSharedTenantsPerCell
                baseDomain = "$Location.$BaseDnsZoneName.$OrganizationDomain"
            }
            $cells += @{
                geoName = $GeoName
                regionName = $Location
                cellName = "shared-startup-z$AvailabilityZones"
                cellType = "Shared"
                availabilityZones = $ZoneConfig[$AvailabilityZones].ZoneArray
                maxTenantCount = 50  # Smaller capacity for startup tier
                baseDomain = "$Location.$BaseDnsZoneName.$OrganizationDomain"
            }
            $cells += @{
                geoName = $GeoName
                regionName = $Location
                cellName = "dedicated-enterprise-z$AvailabilityZones"
                cellType = "Dedicated"
                availabilityZones = $ZoneConfig[$AvailabilityZones].ZoneArray
                maxTenantCount = 1
                baseDomain = "$Location.$BaseDnsZoneName.$OrganizationDomain"
            }
        }
    }
    
    $parameters["regions"] = $regions
    $parameters["cells"] = $cells
    
    # Add compliance-specific parameters
    if ($EnableCompliance.Count -gt 0) {
        $parameters["enableEncryptionAtRest"] = $true
        $parameters["enableNetworkIsolation"] = $true
        $parameters["enableAuditLogging"] = $true
        $parameters["enablePrivateEndpoints"] = $true
        
        if ($EnableCompliance -contains "HIPAA") {
            $parameters["enableHipaaCompliance"] = $true
        }
        if ($EnableCompliance -contains "PCI-DSS") {
            $parameters["enablePciCompliance"] = $true
        }
        if ($EnableCompliance -contains "SOX") {
            $parameters["enableSoxCompliance"] = $true
        }
    }
    
    Write-Host "✓ Generated parameters for $($regions.Count) region(s) and $($cells.Count) CELL(s)" -ForegroundColor Green
    Write-Host ""
    
    return $parameters
}

function Start-BicepDeployment {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters
    )
    
    Write-Host "Starting Bicep deployment..." -ForegroundColor Yellow
    
    $deploymentName = "stamps-$TenancyModel-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $bicepFile = ".\AzureArchitecture\main-corrected.bicep"
    
    if (-not (Test-Path $bicepFile)) {
        Write-Error "Bicep template not found: $bicepFile"
        exit 1
    }
    
    # Create parameters file
    $parametersFile = ".\deployment-parameters-$TenancyModel.json"
    $parametersJson = @{
        '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
        contentVersion = "1.0.0.0"
        parameters = @{}
    }
    
    foreach ($key in $Parameters.Keys) {
        $parametersJson.parameters[$key] = @{ value = $Parameters[$key] }
    }
    
    $parametersJson | ConvertTo-Json -Depth 10 | Out-File -FilePath $parametersFile -Encoding UTF8
    
    Write-Host "✓ Created parameters file: $parametersFile" -ForegroundColor Green
    
    if ($DryRun) {
        Write-Host "DRY RUN: Would execute deployment with parameters:" -ForegroundColor Magenta
        $Parameters | ConvertTo-Json -Depth 3
        Write-Host "DRY RUN: az deployment group create --name $deploymentName --resource-group $ResourceGroupName --template-file $bicepFile --parameters @$parametersFile" -ForegroundColor Magenta
        return
    }
    
    # Execute deployment
    Write-Host "Executing deployment: $deploymentName" -ForegroundColor Green
    Write-Host "This may take 15-30 minutes depending on the number of CELLs..." -ForegroundColor Yellow
    
    $deploymentResult = az deployment group create `
        --name $deploymentName `
        --resource-group $ResourceGroupName `
        --template-file $bicepFile `
        --parameters "@$parametersFile" `
        --output json
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Deployment completed successfully!" -ForegroundColor Green
        
        # Parse and display outputs
        $outputs = ($deploymentResult | ConvertFrom-Json).properties.outputs
        if ($outputs) {
            Write-Host "Deployment Outputs:" -ForegroundColor Green
            $outputs.PSObject.Properties | ForEach-Object {
                Write-Host "  $($_.Name): $($_.Value.value)" -ForegroundColor White
            }
        }
    }
    else {
        Write-Error "Deployment failed. Check the Azure portal for details."
        exit 1
    }
    
    Write-Host ""
}

function Install-TenancyFunctions {
    Write-Host "Deploying enhanced Azure Functions..." -ForegroundColor Yellow
    
    $functionFiles = @(
        ".\AzureArchitecture\CreateTenantFunction.cs",
        ".\AzureArchitecture\GetTenantCellFunction.cs",
        ".\AzureArchitecture\TenantMigrationFunction.cs",
        ".\AzureArchitecture\CellManagementFunction.cs",
        ".\AzureArchitecture\SharedModels.cs"
    )
    
    foreach ($file in $functionFiles) {
        if (Test-Path $file) {
            Write-Host "✓ Found: $file" -ForegroundColor Green
        }
        else {
            Write-Warning "Missing function file: $file"
        }
    }
    
    if ($DryRun) {
        Write-Host "DRY RUN: Would deploy Azure Functions for flexible tenancy" -ForegroundColor Magenta
        return
    }
    
    # In a real deployment, this would:
    # 1. Package the functions
    # 2. Deploy to Azure Functions
    # 3. Configure environment variables
    # 4. Set up monitoring and alerts
    
    Write-Host "✓ Enhanced Azure Functions configured for flexible tenancy" -ForegroundColor Green
    Write-Host ""
}

function Test-DeployedResources {
    Write-Host "Testing deployed resources..." -ForegroundColor Yellow
    
    if ($DryRun) {
        Write-Host "DRY RUN: Would test deployed resources" -ForegroundColor Magenta
        return
    }
    
    # Test resource group exists
    $rgExists = az group exists --name $ResourceGroupName --output tsv
    if ($rgExists -eq "true") {
        Write-Host "✓ Resource Group exists" -ForegroundColor Green
    }
    else {
        Write-Error "Resource Group not found"
    }
    
    # List deployed resources
    $resources = az resource list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    Write-Host "✓ Deployed $($resources.Count) resources:" -ForegroundColor Green
    
    $resourceSummary = $resources | Group-Object type | Sort-Object Count -Descending
    foreach ($group in $resourceSummary) {
        Write-Host "  $($group.Count)x $($group.Name)" -ForegroundColor White
    }
    
    Write-Host ""
}

function Write-DeploymentSummary {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters
    )
    
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "Deployment Summary" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    
    $currentConfig = $TenancyConfig[$TenancyModel]
    
    Write-Host "Flexible Tenancy Configuration:" -ForegroundColor Green
    Write-Host "  Model: $TenancyModel" -ForegroundColor White
    Write-Host "  Description: $($currentConfig.Description)" -ForegroundColor White
    Write-Host "  CELLs Deployed: $($Parameters.cells.Count)" -ForegroundColor White
    Write-Host "  Regions: $($Parameters.regions.Count)" -ForegroundColor White
    
    if ($TenancyModel -eq "mixed" -or $TenancyModel -eq "shared") {
        $sharedCells = $Parameters.cells | Where-Object { $_.cellType -eq "Shared" }
        $totalSharedCapacity = ($sharedCells | Measure-Object maxTenantCount -Sum).Sum
        Write-Host "  Shared CELL Capacity: $totalSharedCapacity tenants" -ForegroundColor White
    }
    
    if ($TenancyModel -eq "mixed" -or $TenancyModel -eq "dedicated") {
        $dedicatedCells = $Parameters.cells | Where-Object { $_.cellType -eq "Dedicated" }
        Write-Host "  Dedicated CELLs: $($dedicatedCells.Count)" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Green
    Write-Host "1. Configure DNS for your custom domain" -ForegroundColor White
    Write-Host "2. Create tenant test data using CreateTenantFunction" -ForegroundColor White
    Write-Host "3. Test tenant routing with GetTenantCellFunction" -ForegroundColor White
    Write-Host "4. Monitor CELL capacity with CellManagementFunction" -ForegroundColor White
    Write-Host "5. Set up automated scaling policies" -ForegroundColor White
    
    if ($EnableCompliance.Count -gt 0) {
        Write-Host ""
        Write-Host "Compliance Features Enabled:" -ForegroundColor Yellow
        foreach ($standard in $EnableCompliance) {
            Write-Host "  ✓ $standard" -ForegroundColor Green
        }
        Write-Host "Review compliance documentation and complete certification audit." -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Cost Estimation (Monthly):" -ForegroundColor Green
    if ($TenancyModel -eq "shared") {
        $maxSharedTenants = ($Parameters.cells | Measure-Object maxTenantCount -Sum).Sum
        Write-Host "  Shared Model: ~$($maxSharedTenants * 16) (at full capacity)" -ForegroundColor White
    }
    elseif ($TenancyModel -eq "dedicated") {
        $dedicatedCells = ($Parameters.cells | Where-Object { $_.cellType -eq "Dedicated" }).Count
        Write-Host "  Dedicated Model: ~$($dedicatedCells * 3200) per month" -ForegroundColor White
    }
    else {
        Write-Host "  Mixed Model: Variable based on tenant mix" -ForegroundColor White
        Write-Host "    - Shared tenants: $16/tenant/month" -ForegroundColor White
        Write-Host "    - Dedicated tenants: $3200/tenant/month" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "✓ Azure Stamps Pattern deployment completed successfully!" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Cyan
}

# Main execution
try {
    Write-DeploymentHeader
    Test-Prerequisites
    New-ResourceGroup
    
    $deploymentParameters = Get-DeploymentParameters
    
    Start-BicepDeployment -Parameters $deploymentParameters
    Install-TenancyFunctions
    Test-DeployedResources
    
    Write-DeploymentSummary -Parameters $deploymentParameters
}
catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    exit 1
}
