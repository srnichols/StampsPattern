<#
APIM Sync Script (apim-sync.ps1)
Purpose: Export APIs and policies from primary APIM and import them into secondary APIM instances.

Usage:
  - Configure the variables below or pass as parameters in CI.
  - Requires: Azure CLI (az), the 'apim' extension (az extension add --name apim), and appropriate permissions.

Notes:
  - This is a pragmatic starter script. For production-grade sync you may want to use APIM DevOps Resource Kit or automation with Git-backed APIM configuration.
  - The script uses the APIM management REST endpoint. If your APIM uses custom domains or managed identities for auth, adjust accordingly.
#>
param(
    [string]$PrimaryApimName = 'apim-stamps-global-test',
    [string]$PrimaryRg = 'rg-stamps-global-test',
    [Parameter(Mandatory=$true)] [string[]]$SecondaryApimNames,
    [string]$SubscriptionId = '',
    [string]$ServicePrincipalId = '',
    [string]$ServicePrincipalSecret = '',
    [string]$ServicePrincipalTenant = '',
    [switch]$WhatIf
)

# Helper: ensure az apim extension
if (-not (az extension list --query "[?name=='apim']" -o tsv)) {
    az extension add --name apim | Out-Null
}

# Optionally login with service principal if provided
if ($ServicePrincipalId -and $ServicePrincipalSecret -and $ServicePrincipalTenant) {
    Write-Host "Authenticating with service principal $ServicePrincipalId"
    az login --service-principal -u $ServicePrincipalId -p $ServicePrincipalSecret --tenant $ServicePrincipalTenant | Out-Null
}

Write-Host "APIM Sync: Primary=$PrimaryApimName -> Secondaries=$($SecondaryApimNames -join ',')"

# Get primary APIM management endpoint
try {
    $primary = az apim show --name $PrimaryApimName --resource-group $PrimaryRg --subscription $SubscriptionId --query "properties.managementApiUrl" -o tsv
} catch {
    Write-Error "Failed to get primary APIM management URL: $_"
    exit 1
}
if (-not $primary) { Write-Error "Failed to get primary APIM management URL"; exit 1 }
Write-Host "Primary management URL: $primary"

# Export all APIs from primary into temporary folder
$tmp = Join-Path $env:TEMP "apim-sync-$(Get-Random)"
New-Item -ItemType Directory -Path $tmp | Out-Null

$apis = az apim api list --service-name $PrimaryApimName --resource-group $PrimaryRg --subscription $SubscriptionId -o json | ConvertFrom-Json

foreach ($api in $apis) {
    $apiId = $api.name
    $exportFile = Join-Path $tmp ("$($apiId).api.zip")
    Write-Host "Exporting API $apiId to $exportFile"
    if ($WhatIf) { continue }
    # Use retry loop for transient failures
    $attempt = 0
    $maxAttempts = 3
    while ($attempt -lt $maxAttempts) {
        try {
            az apim api export --service-name $PrimaryApimName --resource-group $PrimaryRg --subscription $SubscriptionId --api-id $apiId --output-file $exportFile --format swagger-link-json | Out-Null
            break
        } catch {
            $attempt++
            Write-Warning "Export failed for $apiId (attempt $attempt): $_"
            Start-Sleep -Seconds (2 * $attempt)
            if ($attempt -ge $maxAttempts) { throw }
        }
    }
}

# Export global policy
$policyFile = Join-Path $tmp 'global-policy.xml'
az apim policy show --service-name $PrimaryApimName --resource-group $PrimaryRg --subscription $SubscriptionId --query "value" -o tsv > $policyFile

# Import into each secondary
foreach ($sec in $SecondaryApimNames) {
    Write-Host "Syncing to $sec"
    # Determine resource group for secondary (best-effort: assume same RG as primary unless user maps differently)
    $secRg = $PrimaryRg
    # For each API artifact, import into secondary
    foreach ($file in Get-ChildItem -Path $tmp -Filter '*.api.zip') {
        $apiFile = $file.FullName
        $apiName = $file.BaseName
        Write-Host "Importing $apiName -> $sec (RG: $secRg)"
        if ($WhatIf) { continue }
        $attempt = 0
        $maxAttempts = 3
        while ($attempt -lt $maxAttempts) {
            try {
                az apim api import --service-name $sec --resource-group $secRg --subscription $SubscriptionId --path $apiName --specification-format swagger-link-json --specification-path $apiFile | Out-Null
                break
            } catch {
                $attempt++
                Write-Warning "Import failed for $apiName -> $sec (attempt $attempt): $_"
                Start-Sleep -Seconds (2 * $attempt)
                if ($attempt -ge $maxAttempts) { throw }
            }
        }
    }
    # Upload global policy
    if (-not $WhatIf) {
        $policyXml = Get-Content -Raw -Path $policyFile
        az apim policy set --service-name $sec --resource-group $secRg --subscription $SubscriptionId --value "$policyXml" | Out-Null
    }
}

Write-Host "APIM sync complete. Temporary files in $tmp"

# TODO: add retries, API versioning, selective import, and policy transformation rules
