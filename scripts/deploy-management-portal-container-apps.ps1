#!/usr/bin/env pwsh

<#
.SYNOPSIS
	Build and deploy the Management Portal to Azure Container Apps

.DESCRIPTION
	This script deploys infrastructure first, builds images, then deploys Container Apps.
	Uses management-portal.parameters.json for configuration.

.PARAMETER ParametersFile
	The path to the parameters JSON file (default: ./AzureArchitecture/management-portal.parameters.json)
#>

param(
	[Parameter(Mandatory = $false)]
	[string]$ParametersFile = "./AzureArchitecture/management-portal.parameters.json"
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Management Portal deployment..." -ForegroundColor Green

# Read parameters from JSON file
if (-not (Test-Path $ParametersFile)) {
	Write-Host "Parameters file not found: $ParametersFile" -ForegroundColor Red
	exit 1
}

$parametersContent = Get-Content $ParametersFile -Raw | ConvertFrom-Json
$ResourceGroupName = $parametersContent.resourceGroupName
$Location = $parametersContent.location
$SubscriptionId = $parametersContent.subscriptionId
$EnvironmentName = $parametersContent.environment

Write-Host "📋 Using parameters:" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "  Location: $Location" -ForegroundColor White
Write-Host "  Subscription: $SubscriptionId" -ForegroundColor White
Write-Host "  Environment: $EnvironmentName" -ForegroundColor White

# Variables - Use deterministic names to avoid creating duplicates
# Generate unique, compliant names using subscription ID
$sub8 = ($SubscriptionId -replace '-', '').Substring(0,8)
$sanitizedEnv = ($EnvironmentName -replace '[^a-z0-9]', '').ToLower()
$containerRegistryName = ("acr{0}{1}" -f $sanitizedEnv, $sub8)
$containerAppsEnvironmentName = "cae-$sanitizedEnv"
$logAnalyticsWorkspaceName = "law-$sanitizedEnv"
$appInsightsName = "ai-$sanitizedEnv"
$cosmosAccountName = ("cosmos-{0}-{1}" -f $sanitizedEnv, $sub8)

# Image tag (login server resolved later)
$portalImageRepo = "stamps-portal:latest"


# Ensure we're logged into Azure and set subscription context
Write-Host "🔐 Ensuring Azure context..." -ForegroundColor Yellow
$accountInfo = az account show --query "id" --output tsv 2>$null
if (-not $accountInfo) {
	Write-Host "You are not logged in. Please run 'az login' and re-run this script." -ForegroundColor Red
	exit 1
}
if ($accountInfo -ne $SubscriptionId) {
	Write-Host "Switching subscription context to $SubscriptionId" -ForegroundColor Yellow
	az account set --subscription $SubscriptionId | Out-Null
}

# Create resource group if it doesn't exist
Write-Host "📁 Ensuring resource group exists..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location --output none

# Phase 1: Deploy base infrastructure only (no Container Apps yet)
Write-Host "🏗️  Phase 1: Deploying base infrastructure..." -ForegroundColor Yellow

# Create Log Analytics Workspace (if it doesn't exist)
Write-Host "📊 Checking Log Analytics Workspace..." -ForegroundColor Yellow
$existingLaw = az monitor log-analytics workspace show --resource-group $ResourceGroupName --workspace-name $logAnalyticsWorkspaceName --output tsv --query "name" 2>$null
if (-not $existingLaw) {
	Write-Host "📊 Creating Log Analytics Workspace..." -ForegroundColor Yellow
	az monitor log-analytics workspace create `
		--resource-group $ResourceGroupName `
		--workspace-name $logAnalyticsWorkspaceName `
		--location $Location `
		--output none
} else {
	Write-Host "✅ Log Analytics Workspace '$logAnalyticsWorkspaceName' already exists, reusing..." -ForegroundColor Green
}

# Get workspace ID for Application Insights
$workspaceId = az monitor log-analytics workspace show `
	--resource-group $ResourceGroupName `
	--workspace-name $logAnalyticsWorkspaceName `
	--query "id" `
	--output tsv

# Create Application Insights (if it doesn't exist)
Write-Host "📈 Checking Application Insights..." -ForegroundColor Yellow
$existingAppInsights = az monitor app-insights component show --app $appInsightsName --resource-group $ResourceGroupName --output tsv --query "name" 2>$null
if (-not $existingAppInsights) {
	Write-Host "📈 Creating Application Insights..." -ForegroundColor Yellow
	az monitor app-insights component create `
		--app $appInsightsName `
		--location $Location `
		--resource-group $ResourceGroupName `
		--workspace $workspaceId `
		--output none
} else {
	Write-Host "✅ Application Insights '$appInsightsName' already exists, reusing..." -ForegroundColor Green
}

# Create Container Registry (if it doesn't exist) - globally unique name
Write-Host "🐳 Checking Container Registry..." -ForegroundColor Yellow
$existingAcr = az acr show --name $containerRegistryName --resource-group $ResourceGroupName --output tsv --query "name" 2>$null
if (-not $existingAcr) {
	Write-Host "🐳 Creating Container Registry..." -ForegroundColor Yellow
	az acr create `
		--resource-group $ResourceGroupName `
		--name $containerRegistryName `
		--sku Basic `
		--admin-enabled true `
		--location $Location `
		--output none
} else {
	Write-Host "✅ Container Registry '$containerRegistryName' already exists, reusing..." -ForegroundColor Green
}

# Create Cosmos DB Account (if it doesn't exist) - globally unique name
Write-Host "🌐 Checking Cosmos DB Account..." -ForegroundColor Yellow
$existingCosmos = az cosmosdb show --name $cosmosAccountName --resource-group $ResourceGroupName --output tsv --query "name" 2>$null
if (-not $existingCosmos) {
	Write-Host "🌐 Creating Cosmos DB Account..." -ForegroundColor Yellow
	az cosmosdb create `
		--resource-group $ResourceGroupName `
		--name $cosmosAccountName `
		--locations regionName=$Location failoverPriority=0 isZoneRedundant=false `
		--capabilities EnableServerless `
		--output none
} else {
	Write-Host "✅ Cosmos DB Account '$cosmosAccountName' already exists, reusing..." -ForegroundColor Green
}

	# Helper to test if Cosmos account is available
	function Test-CosmosExists {
		param([string]$name,[string]$rg)
		try {
			az cosmosdb show --name $name --resource-group $rg --only-show-errors 1>$null 2>$null
			return ($LASTEXITCODE -eq 0)
		} catch { return $false }
	}

	# Create Cosmos DB Database (if it exists / after account is available)
Write-Host "💾 Checking Cosmos DB Database..." -ForegroundColor Yellow
	if ($existingCosmos -or (Test-CosmosExists -name $cosmosAccountName -rg $ResourceGroupName)) {
	$existingDb = az cosmosdb sql database show --account-name $cosmosAccountName --resource-group $ResourceGroupName --name "stamps-control-plane" --output tsv --query "name" 2>$null
	if (-not $existingDb) {
	Write-Host "💾 Creating Cosmos DB Database..." -ForegroundColor Yellow
	az cosmosdb sql database create `
		--resource-group $ResourceGroupName `
		--account-name $cosmosAccountName `
		--name "stamps-control-plane" `
		--output none
	} else {
		Write-Host "✅ Cosmos DB Database 'stamps-control-plane' already exists, reusing..." -ForegroundColor Green
	}
}
if ($existingCosmos -or (Test-CosmosExists -name $cosmosAccountName -rg $ResourceGroupName)) {
	# Create Cosmos DB Containers (if they don't exist)
	Write-Host "📦 Checking Cosmos DB Containers..." -ForegroundColor Yellow

	# Tenants container
	$existingTenants = az cosmosdb sql container show --account-name $cosmosAccountName --resource-group $ResourceGroupName --database-name "stamps-control-plane" --name "tenants" --output tsv --query "name" 2>$null
	if (-not $existingTenants) {
		Write-Host "📦 Creating Tenants container..." -ForegroundColor Yellow
		az cosmosdb sql container create `
			--resource-group $ResourceGroupName `
			--account-name $cosmosAccountName `
			--database-name "stamps-control-plane" `
			--name "tenants" `
			--partition-key-path "/tenantId" `
			--output none
	} else {
		Write-Host "✅ Tenants container already exists, reusing..." -ForegroundColor Green
	}

	# Cells container
	$existingCells = az cosmosdb sql container show --account-name $cosmosAccountName --resource-group $ResourceGroupName --database-name "stamps-control-plane" --name "cells" --output tsv --query "name" 2>$null
	if (-not $existingCells) {
		Write-Host "📦 Creating Cells container..." -ForegroundColor Yellow
		az cosmosdb sql container create `
			--resource-group $ResourceGroupName `
			--account-name $cosmosAccountName `
			--database-name "stamps-control-plane" `
			--name "cells" `
			--partition-key-path "/cellId" `
			--output none
	} else {
		Write-Host "✅ Cells container already exists, reusing..." -ForegroundColor Green
	}

	# Operations container
	$existingOperations = az cosmosdb sql container show --account-name $cosmosAccountName --resource-group $ResourceGroupName --database-name "stamps-control-plane" --name "operations" --output tsv --query "name" 2>$null
	if (-not $existingOperations) {
		Write-Host "📦 Creating Operations container..." -ForegroundColor Yellow
		az cosmosdb sql container create `
			--resource-group $ResourceGroupName `
			--account-name $cosmosAccountName `
			--database-name "stamps-control-plane" `
			--name "operations" `
			--partition-key-path "/tenantId" `
			--ttl 5184000 `
			--output none
	} else {
		Write-Host "✅ Operations container already exists, reusing..." -ForegroundColor Green
	}

	# Catalogs container
	$existingCatalogs = az cosmosdb sql container show --account-name $cosmosAccountName --resource-group $ResourceGroupName --database-name "stamps-control-plane" --name "catalogs" --output tsv --query "name" 2>$null
	if (-not $existingCatalogs) {
		Write-Host "📦 Creating Catalogs container..." -ForegroundColor Yellow
		az cosmosdb sql container create `
			--resource-group $ResourceGroupName `
			--account-name $cosmosAccountName `
			--database-name "stamps-control-plane" `
			--name "catalogs" `
			--partition-key-path "/type" `
			--output none
	} else {
		Write-Host "✅ Catalogs container already exists, reusing..." -ForegroundColor Green
	}
}

# Create Container Apps Environment (if it doesn't exist)
Write-Host "🏢 Checking Container Apps Environment..." -ForegroundColor Yellow
$existingCae = az containerapp env show --name $containerAppsEnvironmentName --resource-group $ResourceGroupName --output tsv --query "name" 2>$null
if (-not $existingCae) {
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
} else {
	Write-Host "✅ Container Apps Environment '$containerAppsEnvironmentName' already exists, reusing..." -ForegroundColor Green
}

# Get Application Insights connection string (needed for container app)
$appInsightsConnectionString = az monitor app-insights component show `
	--app $appInsightsName `
	--resource-group $ResourceGroupName `
	--query "connectionString" `
	--output tsv

# Phase 2: Build and push container images (remote ACR build to avoid local Docker dependency)
Write-Host "🏗️  Phase 2: Building and pushing container images..." -ForegroundColor Yellow
Write-Host "Building Portal container image with ACR Build..." -ForegroundColor Yellow
Push-Location "./management-portal/src/Portal"
try {
	az acr build -r $containerRegistryName -t $portalImageRepo .
	if ($LASTEXITCODE -ne 0) { throw "Portal image ACR build failed" }
}
finally { Pop-Location }


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

# Use the client app ID and tenant ID from parameters
$clientAppId = $parametersContent.managementClientAppId
$tenantId = $parametersContent.managementClientTenantId

# Create or update Portal Container App
Write-Host "🚀 Checking Portal Container App..." -ForegroundColor Yellow
$existingContainerApp = az containerapp show --name "ca-stamps-portal" --resource-group $ResourceGroupName --output tsv --query "name" 2>$null
if (-not $existingContainerApp) {
	Write-Host "🚀 Creating Portal Container App..." -ForegroundColor Yellow
	az containerapp create `
		--name "ca-stamps-portal" `
		--resource-group $ResourceGroupName `
		--environment $containerAppsEnvironmentName `
		--image "$acrLoginServer/$portalImageRepo" `
		--target-port 8080 `
		--ingress external `
		--registry-server $acrLoginServer `
		--registry-username $containerRegistryName `
		--registry-password $acrPassword `
		--secrets "appinsights-connection-string=$appInsightsConnectionString" "cosmos-connection-string=$cosmosConnectionString" "azure-ad-client-id=$clientAppId" "azure-ad-tenant-id=$tenantId" `
		--env-vars "ASPNETCORE_ENVIRONMENT=Production" "APPLICATIONINSIGHTS_CONNECTION_STRING=secretref:appinsights-connection-string" "COSMOS_CONNECTION_STRING=secretref:cosmos-connection-string" "ASPNETCORE_URLS=http://+:8080" "AzureAd__ClientId=secretref:azure-ad-client-id" "AzureAd__TenantId=secretref:azure-ad-tenant-id" "AzureAd__Instance=https://login.microsoftonline.com/" "AzureAd__CallbackPath=/signin-oidc" "AzureAd__SignedOutCallbackPath=/signout-callback-oidc" "RUNNING_IN_PRODUCTION=true" `
		--cpu 0.5 `
		--memory 1Gi `
		--min-replicas 1 `
		--max-replicas 5 `
		--output none
} else {
	Write-Host "✅ Portal Container App already exists, updating image..." -ForegroundColor Green
	az containerapp update `
		--name "ca-stamps-portal" `
		--resource-group $ResourceGroupName `
		--image "$acrLoginServer/$portalImageRepo" `
		--output none
}

# Ensure system-assigned managed identity, grant Reader at subscription scope, and restart active revision
Write-Host "🔑 Ensuring managed identity and Reader permissions for the Portal app..." -ForegroundColor Yellow
try {
	$identity = az containerapp show --name "ca-stamps-portal" --resource-group $ResourceGroupName -o json | ConvertFrom-Json
	$principalId = $identity.identity.principalId

	if (-not $principalId) {
		Write-Host "Enabling system-assigned identity on ca-stamps-portal..." -ForegroundColor Yellow
		az containerapp identity assign --name "ca-stamps-portal" --resource-group $ResourceGroupName --system-assigned | Out-Null
		Start-Sleep -Seconds 5
		$principalId = (az containerapp show --name "ca-stamps-portal" --resource-group $ResourceGroupName --query identity.principalId -o tsv)
	}

	if ($principalId) {
		$scope = "/subscriptions/$SubscriptionId"
		$hasReader = az role assignment list --assignee $principalId --scope $scope --role Reader -o tsv | Select-String . -Quiet
		if (-not $hasReader) {
			Write-Host "Assigning Reader role at subscription scope to the app's managed identity..." -ForegroundColor Yellow
			az role assignment create --assignee $principalId --role Reader --scope $scope | Out-Null
		} else {
			Write-Host "Reader role already present at subscription scope." -ForegroundColor Green
		}

		# Restart active revision to pick up identity and env changes
		$revs = az containerapp revision list --name "ca-stamps-portal" --resource-group $ResourceGroupName -o json | ConvertFrom-Json
		$active = $revs | Where-Object { $_.properties.active -eq $true } | Select-Object -First 1
		if (-not $active) { $active = $revs | Select-Object -First 1 }
		if ($active) {
			Write-Host "Restarting active revision: $($active.name)" -ForegroundColor Yellow
			az containerapp revision restart --name "ca-stamps-portal" --resource-group $ResourceGroupName --revision $active.name | Out-Null
		}
	} else {
		Write-Host "Warning: Managed identity principalId could not be determined." -ForegroundColor Yellow
	}
}
catch {
	Write-Host "Warning: Failed to ensure managed identity/role assignment. You may need to grant Reader manually." -ForegroundColor Yellow
}

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
Write-Host ""
Write-Host "📊 Monitoring:" -ForegroundColor Cyan
Write-Host "  Application Insights: $appInsightsName" -ForegroundColor White
Write-Host "  Log Analytics: $logAnalyticsWorkspaceName" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure Azure Entra ID authentication" -ForegroundColor White
Write-Host "2. Set up custom domain and SSL certificates" -ForegroundColor White
Write-Host "3. Configure monitoring alerts and dashboards" -ForegroundColor White