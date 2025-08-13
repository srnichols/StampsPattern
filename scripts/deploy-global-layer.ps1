#!/usr/bin/env pwsh
# Deploy the global layer with Traffic Manager endpoints pointing to regional Application Gateways

param(
    [Parameter(Mandatory = $false)]
    [string]$HubSubscriptionId = "480cb033-9a92-4912-9d30-c6b7bf795a87",
    
    [Parameter(Mandatory = $false)]
    [string]$HostSubscriptionId = "2fb123ca-e419-4838-9b44-c2eb71a21769",
    
    [Parameter(Mandatory = $false)]
    [string]$HubResourceGroup = "rg-stamps-hub",
    
    [Parameter(Mandatory = $false)]
    [string]$HostResourceGroup = "rg-stamps-host",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "westus2"
)

Write-Host "🌍 Deploying Global Layer with Traffic Manager endpoints..." -ForegroundColor Cyan

# Set to Hub subscription for deployment
Write-Host "Setting subscription to Hub: $HubSubscriptionId" -ForegroundColor Yellow
az account set --subscription $HubSubscriptionId
if ($LASTEXITCODE -ne 0) { throw "Failed to set Hub subscription" }

# Get the regional Application Gateway FQDNs from Host subscription
Write-Host "Getting regional Application Gateway endpoints..." -ForegroundColor Yellow
$agwQuery = @"
resources
| where type =~ 'microsoft.network/applicationgateways'
| where resourceGroup == '$HostResourceGroup'
| where name startswith 'agw-us-'
| mv-expand frontendIPConfig = properties.frontendIPConfigurations
| where isnotempty(frontendIPConfig) and isnotnull(frontendIPConfig.properties) and isnotnull(frontendIPConfig.properties.publicIPAddress)
| extend publicIPId = tostring(frontendIPConfig.properties.publicIPAddress.id)
| join kind=inner (
    resources
    | where type =~ 'microsoft.network/publicipaddresses'
    | project publicIPId = id, publicIPName = name, fqdn = properties.dnsSettings.fqdn
) on `$left.publicIPId == `$right.publicIPId
| project name, location, fqdn
"@

$agwEndpoints = az graph query -q $agwQuery --subscriptions $HostSubscriptionId | ConvertFrom-Json
Write-Host "Found $($agwEndpoints.data.Count) regional endpoints:" -ForegroundColor Green
foreach ($endpoint in $agwEndpoints.data) {
    Write-Host "  - $($endpoint.name) in $($endpoint.location): $($endpoint.fqdn)" -ForegroundColor Gray
}

# Convert to the format expected by Bicep
$regionalEndpoints = @()
foreach ($endpoint in $agwEndpoints.data) {
    $regionalEndpoints += @{
        fqdn = $endpoint.fqdn
        location = $endpoint.location
    }
}

# Create parameters JSON
$parameters = @{
    '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
    contentVersion = "1.0.0.0"
    parameters = @{
        dnsZoneName = @{ value = "stamps.azurestamparch.onmicrosoft.com" }
        trafficManagerName = @{ value = "tm-stamps-global" }
        frontDoorName = @{ value = "fd-stamps-global" }
        functionAppNamePrefix = @{ value = "fa-stamps" }
        functionStorageNamePrefix = @{ value = "stfastamps" }
        globalControlCosmosDbName = @{ value = "cosmos-stamps-control" }
        primaryLocation = @{ value = $Location }
        additionalLocations = @{ value = @("westus3") }
        functionAppRegions = @{ value = @("westus2", "westus3") }
        logAnalyticsWorkspaceName = @{ value = "law-stamps-hub" }
        logAnalyticsWorkspaceLocation = @{ value = $Location }
        enableGlobalFunctions = @{ value = $true }
        enableGlobalCosmos = @{ value = $true }
        regionalEndpoints = @{ value = $regionalEndpoints }
        tags = @{ 
            value = @{
                environment = "test"
                solution = "stamps-pattern"
                purpose = "global-layer"
            }
        }
    }
}

$parametersPath = "e:\GitHub\StampsPattern\AzureArchitecture\hub-main.global.parameters.json"
$parameters | ConvertTo-Json -Depth 10 | Set-Content $parametersPath

Write-Host "Created parameters file: $parametersPath" -ForegroundColor Green

# Deploy the global layer
Write-Host "Deploying global layer with Traffic Manager endpoints..." -ForegroundColor Cyan
$deploymentName = "global-layer-$(Get-Date -Format 'yyyyMMddHHmmss')"

az deployment group create `
    --resource-group $HubResourceGroup `
    --template-file "e:\GitHub\StampsPattern\AzureArchitecture\hub-main.bicep" `
    --parameters "@$parametersPath" `
    --name $deploymentName `
    --verbose

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Global layer deployment completed successfully!" -ForegroundColor Green
    
    # Get the outputs
    Write-Host "Getting deployment outputs..." -ForegroundColor Yellow
    $outputs = az deployment group show --resource-group $HubResourceGroup --name $deploymentName --query properties.outputs | ConvertFrom-Json
    
    if ($outputs.trafficManagerFqdn) {
        Write-Host "🌐 Traffic Manager FQDN: $($outputs.trafficManagerFqdn.value)" -ForegroundColor Cyan
    }
    if ($outputs.frontDoorProfileName) {
        Write-Host "🚪 Front Door Profile: $($outputs.frontDoorProfileName.value)" -ForegroundColor Cyan
    }
} else {
    Write-Host "❌ Global layer deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host "🎉 Global layer deployment script completed!" -ForegroundColor Green
