# PowerShell script to configure post-deployment traffic routing between Front Door, APIM, and Application Gateways
# This script should be run after single-sub-deployment-step1.ps1 completes successfully

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "prod",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "westus2"
)

Write-Host "=== Azure Stamps Pattern - Post-Deployment Traffic Routing Configuration ===" -ForegroundColor Green
Write-Host "Subscription: $SubscriptionId" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow

# Set subscription context
az account set --subscription $SubscriptionId

# Get resource group names
$globalRgName = "rg-stamps-global-$Environment"
$regionalRgPrefix = "rg-stamps-region"

Write-Host "Step 1: Gathering deployed resource information..." -ForegroundColor Cyan

# Get APIM instance
$apimName = "apim-stamps-global-$Environment"
$apim = az apim show --name $apimName --resource-group $globalRgName --query "{name:name, gatewayUrl:gatewayUrl, managementApiUrl:managementApiUrl}" | ConvertFrom-Json

if (-not $apim) {
    Write-Error "APIM instance '$apimName' not found in resource group '$globalRgName'"
    exit 1
}

Write-Host "Found APIM: $($apim.name) - Gateway URL: $($apim.gatewayUrl)" -ForegroundColor Green

# Get Front Door instance
$frontDoorName = "fd-stamps-global"
$frontDoor = az afd profile show --profile-name $frontDoorName --resource-group $globalRgName --query "{name:name, frontDoorId:frontDoorId}" | ConvertFrom-Json

if (-not $frontDoor) {
    Write-Error "Front Door instance '$frontDoorName' not found in resource group '$globalRgName'"
    exit 1
}

Write-Host "Found Front Door: $($frontDoor.name)" -ForegroundColor Green

# Get Traffic Manager instance
$trafficManagerName = "tm-stamps-global"
$trafficManager = az network traffic-manager profile show --name $trafficManagerName --resource-group $globalRgName --query "{name:name, fqdn:dnsConfig.fqdn}" | ConvertFrom-Json

if (-not $trafficManager) {
    Write-Error "Traffic Manager instance '$trafficManagerName' not found in resource group '$globalRgName'"
    exit 1
}

Write-Host "Found Traffic Manager: $($trafficManager.name) - FQDN: $($trafficManager.fqdn)" -ForegroundColor Green

# Get regional Application Gateways
Write-Host "Step 2: Discovering regional Application Gateways..." -ForegroundColor Cyan

$resourceGroups = az group list --query "[?starts_with(name, '$regionalRgPrefix')].name" --output tsv
$appGateways = @()

foreach ($rgName in $resourceGroups) {
    $agw = az network application-gateway list --resource-group $rgName --query "[0].{name:name, fqdn:frontendIPConfigurations[0].publicIPAddress.fqdn, location:location}" | ConvertFrom-Json
    if ($agw) {
        # Get the actual public IP FQDN
        $pipName = az network application-gateway show --name $agw.name --resource-group $rgName --query "frontendIPConfigurations[0].publicIPAddress.id" --output tsv | Split-Path -Leaf
        $pip = az network public-ip show --name $pipName --resource-group $rgName --query "{fqdn:dnsSettings.fqdn, ipAddress:ipAddress}" | ConvertFrom-Json
        
        $appGateways += @{
            name = $agw.name
            resourceGroup = $rgName
            location = $agw.location
            fqdn = $pip.fqdn
            ipAddress = $pip.ipAddress
        }
        
        Write-Host "Found App Gateway: $($agw.name) in $($agw.location) - FQDN: $($pip.fqdn)" -ForegroundColor Green
    }
}

if ($appGateways.Count -eq 0) {
    Write-Error "No Application Gateways found in regional resource groups"
    exit 1
}

Write-Host "Step 3: Configuring APIM backends for regional Application Gateways..." -ForegroundColor Cyan

# Configure APIM backends for each regional Application Gateway
foreach ($agw in $appGateways) {
    $backendName = "agw-$($agw.location)-backend"
    $backendUrl = "https://$($agw.fqdn)"
    
    Write-Host "Configuring APIM backend: $backendName -> $backendUrl" -ForegroundColor Yellow
    
    # Create or update APIM backend
    $backendConfig = @{
        url = $backendUrl
        protocol = "http"
        title = "Application Gateway - $($agw.location)"
        description = "Regional Application Gateway for $($agw.location)"
    } | ConvertTo-Json
    
    az apim api backend create --service-name $apimName --resource-group $globalRgName --backend-id $backendName --url $backendUrl --protocol http --title "App Gateway $($agw.location)"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Backend may already exist, attempting update..." -ForegroundColor Yellow
        az apim api backend update --service-name $apimName --resource-group $globalRgName --backend-id $backendName --url $backendUrl
    }
}

Write-Host "Step 4: Configuring Front Door origin group with APIM..." -ForegroundColor Cyan

# Get the APIM gateway hostname (without https://)
$apimHostname = $apim.gatewayUrl -replace "https://", ""

# Create origin group for APIM
$originGroupName = "apim-global-origins"

Write-Host "Creating Front Door origin group: $originGroupName" -ForegroundColor Yellow

# Create origin group
az afd origin-group create --profile-name $frontDoorName --resource-group $globalRgName --origin-group-name $originGroupName --probe-request-type GET --probe-protocol Https --probe-interval-in-seconds 100 --probe-path '/health' --sample-size 4 --successful-samples-required 3 --additional-latency-in-milliseconds 50

# Create origin for APIM
$originName = "apim-global-origin"
Write-Host "Creating Front Door origin: $originName -> $apimHostname" -ForegroundColor Yellow

az afd origin create --profile-name $frontDoorName --resource-group $globalRgName --origin-group-name $originGroupName --origin-name $originName --host-name $apimHostname --origin-host-header $apimHostname --http-port 80 --https-port 443 --priority 1 --weight 1000 --enabled-state Enabled

Write-Host "Step 5: Configuring Front Door endpoint and route..." -ForegroundColor Cyan

# Get the Front Door endpoint
$endpointName = "stamps-global-endpoint"
$endpoint = az afd endpoint show --profile-name $frontDoorName --resource-group $globalRgName --endpoint-name $endpointName --query "{name:name, hostName:hostName}" | ConvertFrom-Json

if (-not $endpoint) {
    Write-Error "Front Door endpoint '$endpointName' not found"
    exit 1
}

# Create route to forward all traffic to APIM
$routeName = "apim-route"
Write-Host "Creating Front Door route: $routeName" -ForegroundColor Yellow

az afd route create --profile-name $frontDoorName --resource-group $globalRgName --endpoint-name $endpointName --route-name $routeName --origin-group $originGroupName --supported-protocols Http Https --link-to-default-domain Enabled --forwarding-protocol HttpsOnly --https-redirect Enabled --patterns-to-match "/*"

Write-Host "Step 6: Configuring Traffic Manager endpoints..." -ForegroundColor Cyan

# Add Application Gateway endpoints to Traffic Manager
$endpointIndex = 1
foreach ($agw in $appGateways) {
    $endpointName = "agw-$($agw.location)-endpoint"
    Write-Host "Adding Traffic Manager endpoint: $endpointName -> $($agw.fqdn)" -ForegroundColor Yellow
    
    az network traffic-manager endpoint create --name $endpointName --profile-name $trafficManagerName --resource-group $globalRgName --type externalEndpoints --target $agw.fqdn --endpoint-location $agw.location --endpoint-status Enabled --weight 1 --priority $endpointIndex
    
    $endpointIndex++
}

Write-Host "Step 7: Updating APIM global policy for tenant routing..." -ForegroundColor Cyan

# Create enhanced APIM policy with dynamic backend routing
$apimPolicyXml = @"
<policies>
  <inbound>
    <!-- Global security headers -->
    <set-header name="X-Frame-Options" exists-action="override">
      <value>DENY</value>
    </set-header>
    <set-header name="X-Content-Type-Options" exists-action="override">
      <value>nosniff</value>
    </set-header>
    <set-header name="Strict-Transport-Security" exists-action="override">
      <value>max-age=31536000; includeSubDomains</value>
    </set-header>
    
    <!-- Rate limiting by tenant -->
    <rate-limit-by-key calls="1000" renewal-period="60" counter-key="@(context.Request.Headers.GetValueOrDefault("X-Tenant-ID","anonymous"))" />
    
    <!-- Extract tenant ID from JWT or header -->
    <set-variable name="tenantId" value="@(context.Request.Headers.GetValueOrDefault("X-Tenant-ID",""))" />
    
    <!-- Dynamic backend selection based on tenant region -->
    <choose>
      <when condition="@(((string)context.Variables["tenantId"]).StartsWith("eastus"))">
        <set-backend-service backend-id="agw-eastus-backend" />
      </when>
      <when condition="@(((string)context.Variables["tenantId"]).StartsWith("westus"))">
        <set-backend-service backend-id="agw-westus2-backend" />
      </when>
      <otherwise>
        <!-- Default to first available region -->
        <set-backend-service backend-id="agw-eastus-backend" />
      </otherwise>
    </choose>
    
    <!-- Add tenant context headers for downstream services -->
    <set-header name="X-Processed-By" exists-action="override">
      <value>APIM-Global</value>
    </set-header>
  </inbound>
  <backend>
    <forward-request />
  </backend>
  <outbound>
    <!-- Remove sensitive headers -->
    <set-header name="Server" exists-action="delete" />
    <set-header name="X-Powered-By" exists-action="delete" />
  </outbound>
  <on-error>
    <trace source="@(context.RequestId)" severity="error">
      @{
        return new JObject(
          new JProperty("timestamp", DateTime.UtcNow),
          new JProperty("error", context.LastError.Message),
          new JProperty("requestId", context.RequestId)
        ).ToString();
      }
    </trace>
  </on-error>
</policies>
"@

# Apply the updated policy to APIM
Write-Host "Applying updated APIM global policy..." -ForegroundColor Yellow
$policyFile = [System.IO.Path]::GetTempFileName()
$apimPolicyXml | Out-File -FilePath $policyFile -Encoding UTF8

az apim api policy create --service-name $apimName --resource-group $globalRgName --policy-file $policyFile

Remove-Item $policyFile

Write-Host "Step 8: Configuration Summary" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "Traffic Flow Configured:" -ForegroundColor White
Write-Host "1. User Request -> Front Door ($($endpoint.hostName))" -ForegroundColor White
Write-Host "2. Front Door -> APIM Global ($apimHostname)" -ForegroundColor White
Write-Host "3. APIM -> Regional App Gateways:" -ForegroundColor White
foreach ($agw in $appGateways) {
    Write-Host "   - $($agw.location): $($agw.fqdn)" -ForegroundColor White
}
Write-Host "4. App Gateway -> Regional CELLs" -ForegroundColor White
Write-Host ""
Write-Host "Global Entry Points:" -ForegroundColor Yellow
Write-Host "- Front Door: https://$($endpoint.hostName)" -ForegroundColor White
Write-Host "- Traffic Manager: https://$($trafficManager.fqdn)" -ForegroundColor White
Write-Host "- APIM Gateway: $($apim.gatewayUrl)" -ForegroundColor White
Write-Host ""
Write-Host "Configuration completed successfully!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

# Create verification commands
Write-Host "Verification Commands:" -ForegroundColor Yellow
Write-Host "Test Front Door: curl -I https://$($endpoint.hostName)/health" -ForegroundColor White
Write-Host "Test APIM: curl -I $($apim.gatewayUrl)/health" -ForegroundColor White
Write-Host "Test Traffic Manager: curl -I https://$($trafficManager.fqdn)/health" -ForegroundColor White