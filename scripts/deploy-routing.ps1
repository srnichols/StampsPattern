#!/usr/bin/env pwsh

# Step 2: Validate global routing using outputs from Step 1.
# Usage: pwsh ./scripts/deploy-routing.ps1 -ParametersFile ./AzureArchitecture/routing.parameters.json [-MgmtParamsFile ./AzureArchitecture/management-portal.parameters.json]

param(
    [Parameter(Mandatory = $false)]
    [string]$ParametersFile = "./AzureArchitecture/routing.parameters.json",
    [Parameter(Mandatory = $false)]
    [string]$MgmtParamsFile = "./AzureArchitecture/management-portal.parameters.json"
)

$ErrorActionPreference = "Stop"

Write-Host "🚦 Step 2: Routing validation starting..." -ForegroundColor Green

if (-not (Test-Path $ParametersFile)) {
    Write-Host "Parameters file not found: $ParametersFile" -ForegroundColor Red
    exit 1
}

$routing = Get-Content $ParametersFile -Raw | ConvertFrom-Json

# These are produced by Step 1 as outputs from globalLayer
$dnsZoneName = $routing.dnsZoneName.value
$tmFqdn = $routing.trafficManagerFqdn.value
$fdProfileName = $routing.frontDoorProfileName.value
$fdEndpointHostname = $routing.frontDoorEndpointHostname.value
$functionAppNames = @()
if ($routing.functionAppNames -and $routing.functionAppNames.value) { $functionAppNames = $routing.functionAppNames.value }

# Optionally read management portal params to get env/subscription
$SubscriptionId = $null
$EnvironmentName = $null
if (Test-Path $MgmtParamsFile) {
    $mgmt = Get-Content $MgmtParamsFile -Raw | ConvertFrom-Json
    $SubscriptionId = $mgmt.subscriptionId
    $EnvironmentName = $mgmt.environment
}

if ($SubscriptionId) {
    Write-Host "🔑 Setting subscription: $SubscriptionId" -ForegroundColor Cyan
    az account set --subscription $SubscriptionId | Out-Null
}

$globalRg = $null
if ($EnvironmentName) { $globalRg = "rg-stamps-global-$EnvironmentName" }

Write-Host "📋 Routing artifacts:" -ForegroundColor Cyan
Write-Host "  DNS Zone: $dnsZoneName" -ForegroundColor White
Write-Host "  Traffic Manager FQDN: $tmFqdn" -ForegroundColor White
Write-Host "  Front Door Profile: $fdProfileName" -ForegroundColor White
Write-Host "  Front Door Endpoint Hostname: $fdEndpointHostname" -ForegroundColor White
if ($functionAppNames.Count -gt 0) { Write-Host "  Function Apps: $($functionAppNames -join ', ')" -ForegroundColor White }

# DNS validation helper
function Test-Dns {
    param([string]$Name)
    try {
        Resolve-DnsName -Name $Name -ErrorAction Stop | Out-Null
        return $true
    } catch {
        try {
            nslookup $Name 2>$null | Out-Null
            return ($LASTEXITCODE -eq 0)
        } catch { return $false }
    }
}

# Validate Front Door endpoint resolves
Write-Host "🔎 Validating Front Door endpoint DNS..." -ForegroundColor Yellow
if (Test-Dns -Name $fdEndpointHostname) {
    Write-Host "✅ Front Door DNS resolves: $fdEndpointHostname" -ForegroundColor Green
} else {
    Write-Host "❌ Front Door DNS does not resolve yet: $fdEndpointHostname" -ForegroundColor Red
}

# Validate Traffic Manager FQDN resolves
Write-Host "🔎 Validating Traffic Manager DNS..." -ForegroundColor Yellow
if (Test-Dns -Name $tmFqdn) {
    Write-Host "✅ Traffic Manager DNS resolves: $tmFqdn" -ForegroundColor Green
} else {
    Write-Host "❌ Traffic Manager DNS does not resolve yet: $tmFqdn" -ForegroundColor Red
}

# Optional Azure-side checks (best-effort)
if ($globalRg -and $fdProfileName) {
    try {
    $fd = az afd profile show -g $globalRg -n $fdProfileName -o json | ConvertFrom-Json
    if ($fd -and $fd.name) { Write-Host "✅ Front Door profile found in ${globalRg}: $($fd.name)" -ForegroundColor Green }
    } catch { Write-Host "⚠️ Could not query Front Door profile in ${globalRg}: $($_.Exception.Message)" -ForegroundColor DarkYellow }
}

Write-Host "✅ Step 2 validation complete." -ForegroundColor Green
