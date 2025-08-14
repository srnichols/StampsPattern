#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Build and deploy the Management Portal to Azure Container Apps

.DESCRIPTION
    This script builds the container images, pushes them to Azure Container Registry,
    and deploys the infrastructure using Bicep templates.

.PARAMETER ResourceGroupName
    The name of the resource group to deploy to

.PARAMETER Location
    The Azure region to deploy to (default: westus2)

.PARAMETER SubscriptionId
    The Azure subscription ID

.PARAMETER EnvironmentName
    The environment name for naming resources (default: stamps-mgmt)
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "westus2",
    
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$EnvironmentName = "stamps-mgmt"
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Management Portal deployment..." -ForegroundColor Green

# Variables
$containerRegistryName = "cr$($EnvironmentName.Replace('-', ''))$(Get-Random -Minimum 1000 -Maximum 9999)"
$containerAppsEnvironmentName = "cae-$EnvironmentName"
$logAnalyticsWorkspaceName = "law-$EnvironmentName"
$appInsightsName = "ai-$EnvironmentName"
$cosmosAccountName = "cosmos-$EnvironmentName-$(Get-Random -Minimum 1000 -Maximum 9999)"

$portalImage = "$containerRegistryName.azurecr.io/stamps-portal:latest"
$dabImage = "$containerRegistryName.azurecr.io/stamps-dab:latest"

# Ensure we're logged into Azure
Write-Host "🔐 Checking Azure login..." -ForegroundColor Yellow
$accountInfo = az account show --query "id" --output tsv 2>$null
if (-not $accountInfo -or $accountInfo -ne $SubscriptionId) {
    Write-Host "Please log into Azure and set the correct subscription:" -ForegroundColor Red
    Write-Host "  az login" -ForegroundColor White
    Write-Host "  az account set --subscription $SubscriptionId" -ForegroundColor White
    exit 1
}

# Create resource group if it doesn't exist
Write-Host "📁 Ensuring resource group exists..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location --output none

# Deploy infrastructure first (without container apps)
Write-Host "🏗️  Deploying base infrastructure..." -ForegroundColor Yellow
$deploymentResult = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "infra/management-portal.bicep" `
    --parameters location=$Location `
    --parameters cosmosAccountName=$cosmosAccountName `
    --parameters containerAppsEnvironmentName=$containerAppsEnvironmentName `
    --parameters containerRegistryName=$containerRegistryName `
    --parameters logAnalyticsWorkspaceName=$logAnalyticsWorkspaceName `
    --parameters appInsightsName=$appInsightsName `
    --parameters portalImage="$portalImage" `
    --parameters dabImage="$dabImage" `
    --query "properties.outputs" `
    --output json

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Infrastructure deployment failed!" -ForegroundColor Red
    exit 1
}

$outputs = $deploymentResult | ConvertFrom-Json
$registryLoginServer = $outputs.containerRegistryLoginServer.value

# Log into Container Registry
Write-Host "🔐 Logging into Container Registry..." -ForegroundColor Yellow
az acr login --name $containerRegistryName

# Build and push Portal image
Write-Host "📦 Building Portal container image..." -ForegroundColor Yellow
Push-Location "src/Portal"
try {
    docker build -t $portalImage .
    if ($LASTEXITCODE -ne 0) {
        throw "Portal image build failed"
    }
    
    Write-Host "📤 Pushing Portal image to registry..." -ForegroundColor Yellow
    docker push $portalImage
    if ($LASTEXITCODE -ne 0) {
        throw "Portal image push failed"
    }
}
finally {
    Pop-Location
}

# Build and push DAB image
Write-Host "📦 Building DAB container image..." -ForegroundColor Yellow
Push-Location "dab"
try {
    docker build -t $dabImage .
    if ($LASTEXITCODE -ne 0) {
        throw "DAB image build failed"
    }
    
    Write-Host "📤 Pushing DAB image to registry..." -ForegroundColor Yellow
    docker push $dabImage
    if ($LASTEXITCODE -ne 0) {
        throw "DAB image push failed"
    }
}
finally {
    Pop-Location
}

# Update container apps with the built images
Write-Host "🔄 Updating Container Apps with new images..." -ForegroundColor Yellow
az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "infra/management-portal.bicep" `
    --parameters location=$Location `
    --parameters cosmosAccountName=$cosmosAccountName `
    --parameters containerAppsEnvironmentName=$containerAppsEnvironmentName `
    --parameters containerRegistryName=$containerRegistryName `
    --parameters logAnalyticsWorkspaceName=$logAnalyticsWorkspaceName `
    --parameters appInsightsName=$appInsightsName `
    --parameters portalImage="$portalImage" `
    --parameters dabImage="$dabImage" `
    --output none

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Container Apps update failed!" -ForegroundColor Red
    exit 1
}

# Get final outputs
$finalOutputs = az deployment group show `
    --resource-group $ResourceGroupName `
    --name "management-portal" `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Deployment Summary:" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "  Location: $Location" -ForegroundColor White
Write-Host "  Container Registry: $containerRegistryName" -ForegroundColor White
Write-Host ""
Write-Host "🌐 Application URLs:" -ForegroundColor Cyan
Write-Host "  Portal: $($finalOutputs.portalUrl.value)" -ForegroundColor White
Write-Host "  Data API Builder: $($finalOutputs.dabUrl.value)" -ForegroundColor White
Write-Host ""
Write-Host "📊 Monitoring:" -ForegroundColor Cyan
Write-Host "  Application Insights: $appInsightsName" -ForegroundColor White
Write-Host "  Log Analytics: $logAnalyticsWorkspaceName" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure Azure Entra ID authentication" -ForegroundColor White
Write-Host "2. Set up custom domain and SSL certificates" -ForegroundColor White
Write-Host "3. Configure monitoring alerts and dashboards" -ForegroundColor White
