#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Build and deploy the Management Portal to Azure Container Apps

.DESCRIPTION
    This script deploys infrastructure first, builds images, then deploys Container Apps.

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

# Phase 1: Deploy base infrastructure only (no Container Apps yet)
Write-Host "🏗️  Phase 1: Deploying base infrastructure..." -ForegroundColor Yellow

# Create Log Analytics Workspace
Write-Host "📊 Creating Log Analytics Workspace..." -ForegroundColor Yellow
az monitor log-analytics workspace create `
    --resource-group $ResourceGroupName `
    --workspace-name $logAnalyticsWorkspaceName `
    --location $Location `
    --output none

# Get workspace ID for Application Insights
$workspaceId = az monitor log-analytics workspace show `
    --resource-group $ResourceGroupName `
    --workspace-name $logAnalyticsWorkspaceName `
    --query "id" `
    --output tsv

# Create Application Insights
Write-Host "📈 Creating Application Insights..." -ForegroundColor Yellow
az monitor app-insights component create `
    --app $appInsightsName `
    --location $Location `
    --resource-group $ResourceGroupName `
    --workspace $workspaceId `
    --output none

# Create Container Registry
Write-Host "🐳 Creating Container Registry..." -ForegroundColor Yellow
az acr create `
    --resource-group $ResourceGroupName `
    --name $containerRegistryName `
    --sku Basic `
    --admin-enabled true `
    --location $Location `
    --output none

# Create Cosmos DB Account
Write-Host "🌐 Creating Cosmos DB Account..." -ForegroundColor Yellow
az cosmosdb create `
    --resource-group $ResourceGroupName `
    --name $cosmosAccountName `
    --locations regionName=$Location failoverPriority=0 isZoneRedundant=false `
    --capabilities EnableServerless `
    --output none

# Create Cosmos DB Database
Write-Host "💾 Creating Cosmos DB Database..." -ForegroundColor Yellow
az cosmosdb sql database create `
    --resource-group $ResourceGroupName `
    --account-name $cosmosAccountName `
    --name "stamps-control-plane" `
    --output none

# Create Cosmos DB Containers
Write-Host "📦 Creating Cosmos DB Containers..." -ForegroundColor Yellow

# Tenants container
az cosmosdb sql container create `
    --resource-group $ResourceGroupName `
    --account-name $cosmosAccountName `
    --database-name "stamps-control-plane" `
    --name "tenants" `
    --partition-key-path "/tenantId" `
    --output none

# Cells container
az cosmosdb sql container create `
    --resource-group $ResourceGroupName `
    --account-name $cosmosAccountName `
    --database-name "stamps-control-plane" `
    --name "cells" `
    --partition-key-path "/cellId" `
    --output none

# Operations container
az cosmosdb sql container create `
    --resource-group $ResourceGroupName `
    --account-name $cosmosAccountName `
    --database-name "stamps-control-plane" `
    --name "operations" `
    --partition-key-path "/tenantId" `
    --ttl 5184000 `
    --output none

# Catalogs container
az cosmosdb sql container create `
    --resource-group $ResourceGroupName `
    --account-name $cosmosAccountName `
    --database-name "stamps-control-plane" `
    --name "catalogs" `
    --partition-key-path "/type" `
    --output none

# Create Container Apps Environment
Write-Host "🏢 Creating Container Apps Environment..." -ForegroundColor Yellow

# Get Log Analytics keys
$workspaceCustomerId = az monitor log-analytics workspace show `
    --resource-group $ResourceGroupName `
    --workspace-name $logAnalyticsWorkspaceName `
    --query "customerId" `
    --output tsv

$workspaceKey = az monitor log-analytics workspace get-shared-keys `
    --resource-group $ResourceGroupName `
    --workspace-name $logAnalyticsWorkspaceName `
    --query "primarySharedKey" `
    --output tsv

# Get Application Insights connection string
$appInsightsConnectionString = az monitor app-insights component show `
    --app $appInsightsName `
    --resource-group $ResourceGroupName `
    --query "connectionString" `
    --output tsv

az containerapp env create `
    --name $containerAppsEnvironmentName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --logs-workspace-id $workspaceCustomerId `
    --logs-workspace-key $workspaceKey `
    --dapr-instrumentation-key $(az monitor app-insights component show --app $appInsightsName --resource-group $ResourceGroupName --query "instrumentationKey" --output tsv) `
    --output none

# Phase 2: Build and push container images
Write-Host "🏗️  Phase 2: Building and pushing container images..." -ForegroundColor Yellow

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

# Phase 3: Deploy Container Apps
Write-Host "🏗️  Phase 3: Deploying Container Apps..." -ForegroundColor Yellow

# Get required values
$cosmosConnectionString = az cosmosdb keys list `
    --name $cosmosAccountName `
    --resource-group $ResourceGroupName `
    --type connection-strings `
    --query "connectionStrings[0].connectionString" `
    --output tsv

$acrLoginServer = az acr show `
    --name $containerRegistryName `
    --resource-group $ResourceGroupName `
    --query "loginServer" `
    --output tsv

$acrPassword = az acr credential show `
    --name $containerRegistryName `
    --query "passwords[0].value" `
    --output tsv

# Create DAB Container App
Write-Host "🚀 Creating DAB Container App..." -ForegroundColor Yellow
az containerapp create `
    --name "ca-stamps-dab" `
    --resource-group $ResourceGroupName `
    --environment $containerAppsEnvironmentName `
    --image $dabImage `
    --target-port 80 `
    --ingress external `
    --registry-server $acrLoginServer `
    --registry-username $containerRegistryName `
    --registry-password $acrPassword `
    --secrets "cosmos-connection-string=$cosmosConnectionString" "appinsights-connection-string=$appInsightsConnectionString" `
    --env-vars "COSMOS_CONNECTION_STRING=secretref:cosmos-connection-string" "ASPNETCORE_ENVIRONMENT=Production" "APPLICATIONINSIGHTS_CONNECTION_STRING=secretref:appinsights-connection-string" `
    --cpu 0.25 `
    --memory 0.5Gi `
    --min-replicas 1 `
    --max-replicas 3 `
    --output none

# Get DAB URL
$dabUrl = az containerapp show `
    --name "ca-stamps-dab" `
    --resource-group $ResourceGroupName `
    --query "properties.configuration.ingress.fqdn" `
    --output tsv

# Create Portal Container App
Write-Host "🚀 Creating Portal Container App..." -ForegroundColor Yellow
az containerapp create `
    --name "ca-stamps-portal" `
    --resource-group $ResourceGroupName `
    --environment $containerAppsEnvironmentName `
    --image $portalImage `
    --target-port 8080 `
    --ingress external `
    --registry-server $acrLoginServer `
    --registry-username $containerRegistryName `
    --registry-password $acrPassword `
    --secrets "dab-graphql-url=https://$dabUrl/graphql" "appinsights-connection-string=$appInsightsConnectionString" "azure-ad-client-id=e691193e-4e25-4a72-9185-1ce411aa2fd8" "azure-ad-tenant-id=16b3c013-d300-468d-ac64-7eda0820b6d3" `
    --env-vars "DAB_GRAPHQL_URL=secretref:dab-graphql-url" "ASPNETCORE_ENVIRONMENT=Production" "APPLICATIONINSIGHTS_CONNECTION_STRING=secretref:appinsights-connection-string" "ASPNETCORE_URLS=http://+:8080" "AzureAd__ClientId=secretref:azure-ad-client-id" "AzureAd__TenantId=secretref:azure-ad-tenant-id" "AzureAd__Instance=https://login.microsoftonline.com/" "AzureAd__CallbackPath=/signin-oidc" "AzureAd__SignedOutCallbackPath=/signout-callback-oidc" "RUNNING_IN_PRODUCTION=true" `
    --cpu 0.5 `
    --memory 1Gi `
    --min-replicas 1 `
    --max-replicas 5 `
    --output none

# Get Portal URL
$portalUrl = az containerapp show `
    --name "ca-stamps-portal" `
    --resource-group $ResourceGroupName `
    --query "properties.configuration.ingress.fqdn" `
    --output tsv

Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Deployment Summary:" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "  Location: $Location" -ForegroundColor White
Write-Host "  Container Registry: $containerRegistryName" -ForegroundColor White
Write-Host ""
Write-Host "🌐 Application URLs:" -ForegroundColor Cyan
Write-Host "  Portal: https://$portalUrl" -ForegroundColor White
Write-Host "  Data API Builder: https://$dabUrl" -ForegroundColor White
Write-Host ""
Write-Host "📊 Monitoring:" -ForegroundColor Cyan
Write-Host "  Application Insights: $appInsightsName" -ForegroundColor White
Write-Host "  Log Analytics: $logAnalyticsWorkspaceName" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure Azure Entra ID authentication" -ForegroundColor White
Write-Host "2. Set up custom domain and SSL certificates" -ForegroundColor White
Write-Host "3. Configure monitoring alerts and dashboards" -ForegroundColor White