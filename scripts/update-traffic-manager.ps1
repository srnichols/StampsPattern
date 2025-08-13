#!/usr/bin/env pwsh
# Update the existing Traffic Manager with regional Application Gateway endpoints

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
    [string]$TrafficManagerName = "tm-stamps-global"
)

Write-Host "🌐 Updating Traffic Manager with regional endpoints..." -ForegroundColor Cyan

# Set to Hub subscription
Write-Host "Setting subscription to Hub: $HubSubscriptionId" -ForegroundColor Yellow
az account set --subscription $HubSubscriptionId
if ($LASTEXITCODE -ne 0) { throw "Failed to set Hub subscription" }

# Get the regional Application Gateway FQDNs from Host subscription
Write-Host "Getting regional Application Gateway endpoints..." -ForegroundColor Yellow

$agwEndpoints = az resource list `
    --resource-group $HostResourceGroup `
    --subscription $HostSubscriptionId `
    --resource-type Microsoft.Network/applicationGateways `
    --query "[?contains(name, 'agw-us-')]" | ConvertFrom-Json

if ($agwEndpoints.Count -eq 0) {
    Write-Host "❌ No Application Gateways found!" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($agwEndpoints.Count) Application Gateways:" -ForegroundColor Green

$endpoints = @()
foreach ($agw in $agwEndpoints) {
    Write-Host "  Processing AGW: $($agw.name) in $($agw.location)" -ForegroundColor Gray
    
    # Get the AGW details to find the public IP
    $agwDetails = az network application-gateway show `
        --name $agw.name `
        --resource-group $HostResourceGroup `
        --subscription $HostSubscriptionId | ConvertFrom-Json
    
    if ($agwDetails.frontendIPConfigurations -and $agwDetails.frontendIPConfigurations.Count -gt 0) {
        $frontendConfig = $agwDetails.frontendIPConfigurations[0]
        if ($frontendConfig.publicIPAddress) {
            $publicIPId = $frontendConfig.publicIPAddress.id
            $publicIPName = $publicIPId.Split('/')[-1]
            
            # Get the public IP details
            $publicIP = az network public-ip show `
                --name $publicIPName `
                --resource-group $HostResourceGroup `
                --subscription $HostSubscriptionId | ConvertFrom-Json
            
            if ($publicIP.dnsSettings -and $publicIP.dnsSettings.fqdn) {
                $endpoints += @{
                    name = "regional-$($agw.location)"
                    fqdn = $publicIP.dnsSettings.fqdn
                    location = $agw.location
                }
                Write-Host "    FQDN: $($publicIP.dnsSettings.fqdn)" -ForegroundColor Green
            }
        }
    }
}

if ($endpoints.Count -eq 0) {
    Write-Host "❌ No Application Gateway endpoints found with FQDNs!" -ForegroundColor Red
    exit 1
}

Write-Host "Adding $($endpoints.Count) endpoints to Traffic Manager..." -ForegroundColor Yellow

# Clear existing endpoints
Write-Host "Clearing existing Traffic Manager endpoints..." -ForegroundColor Yellow
$existingEndpoints = az network traffic-manager endpoint list `
    --profile-name $TrafficManagerName `
    --resource-group $HubResourceGroup `
    --subscription $HubSubscriptionId | ConvertFrom-Json

foreach ($endpoint in $existingEndpoints) {
    Write-Host "  Removing endpoint: $($endpoint.name)" -ForegroundColor Gray
    az network traffic-manager endpoint delete `
        --name $endpoint.name `
        --profile-name $TrafficManagerName `
        --resource-group $HubResourceGroup `
        --subscription $HubSubscriptionId `
        --type $endpoint.type.Split('/')[-1] `
        --yes
}

# Add new endpoints
Write-Host "Adding regional Application Gateway endpoints..." -ForegroundColor Yellow
$priority = 1
foreach ($endpoint in $endpoints) {
    Write-Host "  Adding endpoint: $($endpoint.name) -> $($endpoint.fqdn)" -ForegroundColor Gray
    
    az network traffic-manager endpoint create `
        --name $endpoint.name `
        --profile-name $TrafficManagerName `
        --resource-group $HubResourceGroup `
        --subscription $HubSubscriptionId `
        --type ExternalEndpoints `
        --target $endpoint.fqdn `
        --endpoint-location $endpoint.location `
        --priority $priority `
        --weight 1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to add endpoint: $($endpoint.name)" -ForegroundColor Red
    } else {
        Write-Host "✅ Added endpoint: $($endpoint.name)" -ForegroundColor Green
    }
    
    $priority++
}

# Get Traffic Manager status
Write-Host "Getting Traffic Manager status..." -ForegroundColor Yellow
$tmProfile = az network traffic-manager profile show `
    --name $TrafficManagerName `
    --resource-group $HubResourceGroup `
    --subscription $HubSubscriptionId | ConvertFrom-Json

if ($tmProfile) {
    Write-Host "🌐 Traffic Manager FQDN: $($tmProfile.dnsConfig.fqdn)" -ForegroundColor Cyan
    Write-Host "📊 Traffic Routing Method: $($tmProfile.trafficRoutingMethod)" -ForegroundColor Cyan
    Write-Host "🔍 Monitor Protocol: $($tmProfile.monitorConfig.protocol)" -ForegroundColor Cyan
    Write-Host "🚪 Monitor Port: $($tmProfile.monitorConfig.port)" -ForegroundColor Cyan
    Write-Host "📍 Monitor Path: $($tmProfile.monitorConfig.path)" -ForegroundColor Cyan
}

Write-Host "✅ Traffic Manager update completed!" -ForegroundColor Green
