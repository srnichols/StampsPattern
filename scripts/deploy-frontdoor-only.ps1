#!/usr/bin/env pwsh
# Deploy standalone Azure Front Door Standard without affecting other global resources

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
    [ValidateSet('Standard_AzureFrontDoor', 'Premium_AzureFrontDoor')]
    [string]$FrontDoorSku = "Standard_AzureFrontDoor"
)

Write-Host "🚪 Deploying standalone Azure Front Door $FrontDoorSku..." -ForegroundColor Cyan

# Set to Hub subscription for deployment
Write-Host "Setting subscription to Hub: $HubSubscriptionId" -ForegroundColor Yellow
az account set --subscription $HubSubscriptionId
if ($LASTEXITCODE -ne 0) { throw "Failed to set Hub subscription" }

# Get Log Analytics Workspace ID
Write-Host "Getting Log Analytics workspace..." -ForegroundColor Yellow
$lawId = az monitor log-analytics workspace list --resource-group $HubResourceGroup --query "[?starts_with(name,'law-stamps-hub')].id | [0]" --output tsv

if (-not $lawId) {
    Write-Host "❌ Log Analytics workspace not found!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Found Log Analytics workspace: $lawId" -ForegroundColor Green

# Get the regional Application Gateway FQDNs
Write-Host "Getting regional Application Gateway endpoints..." -ForegroundColor Yellow
az account set --subscription $HostSubscriptionId

# Get AGW FQDNs using a simpler approach
$agwWus2Fqdn = "agw-wus2-tst-rfu3.westus2.cloudapp.azure.com"
$agwWus3Fqdn = "agw-wus3-tst-vrlu.westus3.cloudapp.azure.com"

$regionalEndpoints = @(
    @{
        fqdn = $agwWus2Fqdn
        location = "westus2"
    },
    @{
        fqdn = $agwWus3Fqdn
        location = "westus3"
    }
)

Write-Host "Regional endpoints:" -ForegroundColor Green
foreach ($endpoint in $regionalEndpoints) {
    Write-Host "  - $($endpoint.location): $($endpoint.fqdn)" -ForegroundColor Gray
}

# Switch back to Hub subscription
az account set --subscription $HubSubscriptionId

# Create parameters for the standalone Front Door deployment
$deploymentName = "frontdoor-standalone-$(Get-Date -Format 'yyyyMMddHHmmss')"

Write-Host "Deploying Azure Front Door $FrontDoorSku..." -ForegroundColor Cyan

# Create parameters inline
$parametersJson = @{
    frontDoorName = @{ value = "fd-stamps-global" }
    frontDoorSku = @{ value = $FrontDoorSku }
    regionalEndpoints = @{ value = $regionalEndpoints }
    logAnalyticsWorkspaceId = @{ value = $lawId }
    tags = @{ 
        value = @{
            environment = "test"
            solution = "stamps-pattern"
            purpose = "global-front-door"
            sku = $FrontDoorSku
        }
    }
} | ConvertTo-Json -Depth 10

$parametersPath = "e:\temp\frontdoor-params-$(Get-Date -Format 'yyyyMMddHHmmss').json"
$parametersJson | Set-Content $parametersPath

az deployment group create `
    --resource-group $HubResourceGroup `
    --template-file "e:\GitHub\StampsPattern\AzureArchitecture\frontdoor-standalone.bicep" `
    --parameters "@$parametersPath" `
    --name $deploymentName `
    --verbose

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Azure Front Door $FrontDoorSku deployment completed successfully!" -ForegroundColor Green
    
    # Get the outputs
    Write-Host "Getting deployment outputs..." -ForegroundColor Yellow
    $outputs = az deployment group show --resource-group $HubResourceGroup --name $deploymentName --query properties.outputs | ConvertFrom-Json
    
    Write-Host "🎯 Front Door Details:" -ForegroundColor Cyan
    if ($outputs.frontDoorEndpointHostname) {
        Write-Host "  🚪 Front Door Endpoint: $($outputs.frontDoorEndpointHostname.value)" -ForegroundColor White
        Write-Host "  📊 SKU: $FrontDoorSku" -ForegroundColor White
        Write-Host "  🔗 Origins: $($regionalEndpoints.Count) regional Application Gateways" -ForegroundColor White
        
        # Test the Front Door endpoint
        Write-Host "🔍 Testing Front Door connectivity..." -ForegroundColor Yellow
        Write-Host "   (Note: Front Door may take 5-10 minutes to fully propagate)" -ForegroundColor Gray
        
        Start-Sleep -Seconds 30
        try {
            $frontDoorFqdn = $outputs.frontDoorEndpointHostname.value
            Write-Host "Testing: https://$frontDoorFqdn" -ForegroundColor Gray
            $response = Invoke-WebRequest -Uri "https://$frontDoorFqdn" -Method GET -TimeoutSec 30 -UseBasicParsing -ErrorAction Stop
            Write-Host "✅ Front Door Status: $($response.StatusCode)" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ Front Door test: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "   This is normal for new Front Door deployments - try again in 5-10 minutes" -ForegroundColor Gray
        }
    }
    
    # Cleanup temp file
    Remove-Item $parametersPath -Force -ErrorAction SilentlyContinue
    
} else {
    Write-Host "❌ Azure Front Door deployment failed!" -ForegroundColor Red
    Remove-Item $parametersPath -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "🎉 Azure Front Door $FrontDoorSku deployment completed!" -ForegroundColor Green
