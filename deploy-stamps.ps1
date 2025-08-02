# Azure Stamps Pattern Deployment Script (PowerShell)
# This script deploys the traffic routing infrastructure for the stamps pattern

# Configuration
$Location = "eastus"

# Generate resource group name with region abbreviation
$RegionMapping = @{
    "eastus" = "eus"
    "eastus2" = "eus2"
    "westus" = "wus"
    "westus2" = "wus2"
    "westus3" = "wus3"
    "centralus" = "cus"
    "northeurope" = "neu"
    "westeurope" = "weu"
}

$RegionShort = $RegionMapping[$Location]
if (-not $RegionShort) {
    $RegionShort = $Location.Substring(0, [Math]::Min(3, $Location.Length))
}

$ResourceGroupName = "rg-stamps-$RegionShort-dev"
$TemplateFile = "traffic-routing.bicep"
$ParametersFile = "traffic-routing.parameters.json"

Write-Host "🚀 Starting Azure Stamps Pattern Deployment" -ForegroundColor Green

# Check if user is logged in to Azure
Write-Host "Checking Azure login status..." -ForegroundColor Yellow
try {
    $currentContext = Get-AzContext
    if (-not $currentContext) {
        throw "Not logged in"
    }
    Write-Host "✅ Azure login verified" -ForegroundColor Green
} catch {
    Write-Host "❌ Not logged in to Azure. Please run 'Connect-AzAccount' first." -ForegroundColor Red
    exit 1
}

# Get current subscription
$SubscriptionId = (Get-AzContext).Subscription.Id
Write-Host "📋 Using subscription: $SubscriptionId" -ForegroundColor Green

# Create resource group if it doesn't exist
Write-Host "📦 Creating resource group if it doesn't exist..." -ForegroundColor Yellow
try {
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Force
    Write-Host "✅ Resource group ready" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create resource group: $_" -ForegroundColor Red
    exit 1
}

# Deploy the template
Write-Host "🔧 Deploying Bicep template..." -ForegroundColor Yellow
try {
    $deployment = New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $ParametersFile `
        -Verbose
    
    Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
    
    # Display deployment outputs
    Write-Host "📊 Deployment outputs:" -ForegroundColor Yellow
    $deployment.Outputs | Format-Table -AutoSize
    
} catch {
    Write-Host "❌ Deployment failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "✨ Azure Stamps Pattern deployment complete!" -ForegroundColor Green
