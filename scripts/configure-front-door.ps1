#!/usr/bin/env pwsh
# Configure Front Door to connect to regional Application Gateways

param(
    [Parameter(Mandatory = $false)]
    [string]$HubSubscriptionId = "480cb033-9a92-4912-9d30-c6b7bf795a87",
    
    [Parameter(Mandatory = $false)]
    [string]$HubResourceGroup = "rg-stamps-hub",
    
    [Parameter(Mandatory = $false)]
    [string]$FrontDoorName = "fd-stamps-global",
    
    [Parameter(Mandatory = $false)]
    [string]$EndpointName = "stamps-global-endpoint"
)

Write-Host "🚪 Configuring Front Door with regional backends..." -ForegroundColor Cyan

# Set to Hub subscription
Write-Host "Setting subscription to Hub: $HubSubscriptionId" -ForegroundColor Yellow
az account set --subscription $HubSubscriptionId
if ($LASTEXITCODE -ne 0) { throw "Failed to set Hub subscription" }

# Get the existing Front Door profile
Write-Host "Getting Front Door profile..." -ForegroundColor Yellow
$fdProfile = az cdn profile show `
    --name $FrontDoorName `
    --resource-group $HubResourceGroup | ConvertFrom-Json

if (-not $fdProfile) {
    Write-Host "❌ Front Door profile not found!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Found Front Door profile: $($fdProfile.name)" -ForegroundColor Green

# Regional Application Gateway FQDNs (from our previous deployment)
$regionalEndpoints = @(
    "agw-wus2-tst-rfu3.westus2.cloudapp.azure.com",
    "agw-wus3-tst-vrlu.westus3.cloudapp.azure.com"
)

Write-Host "Regional endpoints to configure:" -ForegroundColor Yellow
foreach ($endpoint in $regionalEndpoints) {
    Write-Host "  - $endpoint" -ForegroundColor Gray
}

# Create or update Front Door endpoint
Write-Host "Creating Front Door endpoint..." -ForegroundColor Yellow
$endpoint = az cdn endpoint create `
    --profile-name $FrontDoorName `
    --resource-group $HubResourceGroup `
    --name $EndpointName `
    --origin-host-header $regionalEndpoints[0] `
    --origin $regionalEndpoints[0] `
    --origin-path "/" `
    --enable-compression true `
    --query-string-caching-behavior "IgnoreQueryString" | ConvertFrom-Json

if ($endpoint) {
    Write-Host "✅ Created Front Door endpoint: $($endpoint.name)" -ForegroundColor Green
    Write-Host "🌐 Endpoint hostname: $($endpoint.hostName)" -ForegroundColor Cyan
    
    # Add additional origins for regional redundancy
    Write-Host "Adding additional regional origins..." -ForegroundColor Yellow
    for ($i = 1; $i -lt $regionalEndpoints.Count; $i++) {
        $originName = "regional-origin-$($i + 1)"
        Write-Host "  Adding origin: $originName -> $($regionalEndpoints[$i])" -ForegroundColor Gray
        
        az cdn origin create `
            --endpoint-name $EndpointName `
            --profile-name $FrontDoorName `
            --resource-group $HubResourceGroup `
            --name $originName `
            --host-name $regionalEndpoints[$i] `
            --origin-host-header $regionalEndpoints[$i] `
            --priority 2 `
            --weight 50 `
            --enabled true
            
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✅ Added origin: $originName" -ForegroundColor Green
        } else {
            Write-Host "    ❌ Failed to add origin: $originName" -ForegroundColor Red
        }
    }
    
    # Configure routing rules
    Write-Host "Configuring routing rules..." -ForegroundColor Yellow
    az cdn endpoint rule add `
        --endpoint-name $EndpointName `
        --profile-name $FrontDoorName `
        --resource-group $HubResourceGroup `
        --order 1 `
        --rule-name "ForwardToRegionalBackends" `
        --match-variable "RequestUri" `
        --operator "Any" `
        --action-name "RouteConfigurationOverride" `
        --forwarding-protocol "HttpsOnly" `
        --custom-forwarding-path "/"
        
} else {
    Write-Host "❌ Failed to create Front Door endpoint!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Front Door configuration completed!" -ForegroundColor Green
