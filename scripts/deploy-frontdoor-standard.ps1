#!/usr/bin/env pwsh
# Deploy Modern Azure Front Door Standard with regional Application Gateway origins

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
    [string]$Location = "westus2",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Standard_AzureFrontDoor', 'Premium_AzureFrontDoor')]
    [string]$FrontDoorSku = "Standard_AzureFrontDoor"
)

Write-Host "🚪 Upgrading to Azure Front Door $FrontDoorSku..." -ForegroundColor Cyan

# Set to Hub subscription for deployment
Write-Host "Setting subscription to Hub: $HubSubscriptionId" -ForegroundColor Yellow
az account set --subscription $HubSubscriptionId
if ($LASTEXITCODE -ne 0) { throw "Failed to set Hub subscription" }

# Get the regional Application Gateway FQDNs from Host subscription
Write-Host "Getting regional Application Gateway endpoints..." -ForegroundColor Yellow
az account set --subscription $HostSubscriptionId
$agwEndpoints = az network application-gateway list --resource-group $HostResourceGroup --query "[?starts_with(name,'agw-us-')].{name:name, location:location}" | ConvertFrom-Json

if (-not $agwEndpoints -or $agwEndpoints.Count -eq 0) {
    Write-Host "❌ No Application Gateways found!" -ForegroundColor Red
    exit 1
}

# Get the public IP FQDNs for each AGW
$regionalEndpoints = @()
foreach ($agw in $agwEndpoints) {
    Write-Host "  Processing AGW: $($agw.name) in $($agw.location)" -ForegroundColor Gray
    
    # Get the public IP associated with this AGW
    $agwDetails = az network application-gateway show --name $agw.name --resource-group $HostResourceGroup | ConvertFrom-Json
    $publicIPId = $agwDetails.frontendIPConfigurations[0].publicIPAddress.id
    $publicIPName = Split-Path $publicIPId -Leaf
    
    $publicIP = az network public-ip show --name $publicIPName --resource-group $HostResourceGroup | ConvertFrom-Json
    $fqdn = $publicIP.dnsSettings.fqdn
    
    Write-Host "    FQDN: $fqdn" -ForegroundColor Gray
    
    $regionalEndpoints += @{
        fqdn = $fqdn
        location = $agw.location
    }
}

# Switch back to Hub subscription
az account set --subscription $HubSubscriptionId

Write-Host "Found $($regionalEndpoints.Count) regional endpoints:" -ForegroundColor Green
foreach ($endpoint in $regionalEndpoints) {
    Write-Host "  - $($endpoint.location): $($endpoint.fqdn)" -ForegroundColor Gray
}

# Check if we need to delete the old legacy Front Door profile first
Write-Host "Checking existing Front Door profile..." -ForegroundColor Yellow
$existingFD = az cdn profile show --name "fd-stamps-global" --resource-group $HubResourceGroup 2>$null | ConvertFrom-Json

if ($existingFD -and $existingFD.sku.name -eq "Standard_Microsoft") {
    Write-Host "⚠️ Found legacy CDN profile. Please delete it manually first." -ForegroundColor Yellow
    Write-Host "Run: az cdn profile delete --name 'fd-stamps-global' --resource-group $HubResourceGroup" -ForegroundColor Gray
    exit 1
} else {
    Write-Host "✅ Ready to deploy modern Front Door" -ForegroundColor Green
}

# Create parameters JSON for the deployment
$parameters = @{
    '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
    contentVersion = "1.0.0.0"
    parameters = @{
        dnsZoneName = @{ value = "stamps.azurestamparch.onmicrosoft.com" }
        trafficManagerName = @{ value = "tm-stamps-global" }
        frontDoorName = @{ value = "fd-stamps-global" }
        frontDoorSku = @{ value = $FrontDoorSku }
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
                frontDoorSku = $FrontDoorSku
            }
        }
    }
}

$parametersPath = "e:\GitHub\StampsPattern\AzureArchitecture\hub-main.frontdoor.parameters.json"
$parameters | ConvertTo-Json -Depth 10 | Set-Content $parametersPath

Write-Host "Created parameters file: $parametersPath" -ForegroundColor Green

# Deploy the upgraded Front Door
Write-Host "Deploying Azure Front Door $FrontDoorSku with regional endpoints..." -ForegroundColor Cyan
$deploymentName = "frontdoor-upgrade-$(Get-Date -Format 'yyyyMMddHHmmss')"

az deployment group create `
    --resource-group $HubResourceGroup `
    --template-file "e:\GitHub\StampsPattern\AzureArchitecture\hub-main.bicep" `
    --parameters "@$parametersPath" `
    --name $deploymentName `
    --verbose

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Azure Front Door $FrontDoorSku deployment completed successfully!" -ForegroundColor Green
    
    # Get the outputs
    Write-Host "Getting deployment outputs..." -ForegroundColor Yellow
    $outputs = az deployment group show --resource-group $HubResourceGroup --name $deploymentName --query properties.outputs | ConvertFrom-Json
    
    Write-Host "🎯 Global Layer Endpoints:" -ForegroundColor Cyan
    if ($outputs.trafficManagerFqdn) {
        Write-Host "  🌐 Traffic Manager: $($outputs.trafficManagerFqdn.value)" -ForegroundColor White
    }
    if ($outputs.frontDoorEndpointHostname) {
        Write-Host "  🚪 Front Door Endpoint: $($outputs.frontDoorEndpointHostname.value)" -ForegroundColor White
    }
    if ($outputs.frontDoorProfileName) {
        Write-Host "  📊 Front Door Profile: $($outputs.frontDoorProfileName.value) ($FrontDoorSku)" -ForegroundColor White
    }
    
    Write-Host "🔍 Testing Front Door connectivity..." -ForegroundColor Yellow
    Start-Sleep -Seconds 60  # Wait for Front Door propagation
    
    try {
        $frontDoorFqdn = $outputs.frontDoorEndpointHostname.value
        Write-Host "Testing: https://$frontDoorFqdn" -ForegroundColor Gray
        $response = Invoke-WebRequest -Uri "https://$frontDoorFqdn" -Method GET -TimeoutSec 30 -UseBasicParsing -ErrorAction Stop
        Write-Host "✅ Front Door Status: $($response.StatusCode) - Content: $($response.Content.Length) chars" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Front Door test: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "   (Front Door may need more time to propagate - try again in a few minutes)" -ForegroundColor Gray
    }
    
} else {
    Write-Host "❌ Azure Front Door deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host "🎉 Azure Front Door $FrontDoorSku upgrade completed!" -ForegroundColor Green
