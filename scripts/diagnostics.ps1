<#
diagnostics.ps1 - lightweight diagnostics for StampsPattern operator

Purpose:
- Run a small set of non-destructive checks to surface common issues (Portal↔GraphQL, container app health, ACR, Cosmos, and managed identities)
- Meant to be run from a workstation with Azure CLI signed-in (az) and PowerShell 7+

Usage (example):
  pwsh -NoProfile -File .\scripts\diagnostics.ps1 -ResourceGroup rg-stamps-mgmt -TailLogs -LogLines 300

This script is intentionally read-only; it will not change role assignments or secrets.
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup = 'rg-stamps-mgmt',
    # GraphQL backend container name or resource name. Defaults to legacy value for compatibility.
    [string]$GraphqlName = 'ca-stamps-dab',
    # Legacy name kept for scripts that still use it; GraphqlName is preferred.
    [string]$DabName = $GraphqlName,
    [string]$PortalName = 'ca-stamps-portal',
    [string]$AcrName = 'crxgjwtecm3g5pi',
    [string]$CosmosName = 'cosmos-xgjwtecm3g5pi',
    [switch]$TailLogs = $false,
    [int]$LogLines = 200
)

function Write-Section([string]$text){
    Write-Host "`n===== $text =====" -ForegroundColor Cyan
}

try{
    Write-Section "Azure CLI version"
    az --version | Select-Object -First 3 | ForEach-Object { Write-Host $_ }
} catch {
    Write-Warning "Azure CLI not found or failed to run. Ensure 'az' is installed and in PATH."
}

try{
    Write-Section "Logged-in account"
    $acct = az account show --output json | ConvertFrom-Json
    Write-Host "Subscription: $($acct.id) ($($acct.name))`nTenant: $($acct.tenantId)"
} catch {
    Write-Warning "Not signed in. Run 'az login' and re-run this script."
}

# Container App checks
Write-Section "Container App: GraphQL backend ($GraphqlName)"
try{
    az containerapp show --name $GraphqlName --resource-group $ResourceGroup --output json | ConvertFrom-Json | Select-Object -Property name,location,@{Name='Ingress';Expression={($_.properties.configuration.ingress)}},@{Name='Identity';Expression={$_.identity}} | Format-List
    Write-Host "Revisions:"
    az containerapp revision list --name $GraphqlName --resource-group $ResourceGroup --output table
    Write-Host "Template containers and env vars:"
    az containerapp show --name $GraphqlName --resource-group $ResourceGroup --query properties.template.containers -o json | ConvertFrom-Json | ForEach-Object { $_ | Select-Object name, image, @{Name='EnvCount';Expression={$_.env.Count}} } | Format-Table -AutoSize
    Write-Host "Secrets (names):"
    az containerapp secret list --name $GraphqlName --resource-group $ResourceGroup -o table
} catch {
    Write-Warning ("Failed to query Container App {0} in {1}: {2}" -f $GraphqlName, $ResourceGroup, $_)
}

Write-Section "Container App: Portal ($PortalName)"
try{
    az containerapp show --name $PortalName --resource-group $ResourceGroup --output json | ConvertFrom-Json | Select-Object -Property name,location,@{Name='Ingress';Expression={($_.properties.configuration.ingress)}},@{Name='Identity';Expression={$_.identity}} | Format-List
    Write-Host "Template containers and env vars:"
    az containerapp show --name $PortalName --resource-group $ResourceGroup --query properties.template.containers -o json | ConvertFrom-Json | ForEach-Object { $_ | Select-Object name, image, @{Name='EnvCount';Expression={$_.env.Count}} } | Format-Table -AutoSize
    Write-Host "Secrets (names):"
    az containerapp secret list --name $PortalName --resource-group $ResourceGroup -o table
} catch {
    Write-Warning ("Failed to query Container App {0} in {1}: {2}" -f $PortalName, $ResourceGroup, $_)
}

if ($TailLogs) {
    Write-Section "Tailing logs ($LogLines lines) for GraphQL container 'dab' (if present)"
    try{
        az containerapp logs show -g $ResourceGroup -n $DabName --container dab --tail $LogLines
    } catch {
        Write-Warning "Failed to tail logs; container name 'dab' may be different or permissions are missing: $_"
    }
}

# ACR checks
Write-Section "ACR: $AcrName repositories (top 20)"
try{
    az acr repository list --name $AcrName --output table --top 20
} catch {
    Write-Warning ("Failed to list ACR repositories for '{0}' (check name or permissions)." -f $AcrName)
}

# Cosmos checks
Write-Section "CosmosDB: $CosmosName"
try{
    $cos = az cosmosdb show --name $CosmosName --resource-group $ResourceGroup --output json | ConvertFrom-Json
    Write-Host "AccountId: $($cos.id)"
    Write-Host "ConsistencyPolicy: $($cos.consistencyPolicy.defaultConsistencyLevel)"
    # list databases (requires listKeys or read permission); try a management-plane call
    Write-Host "Attempting to list SQL databases (management-plane):"
    az cosmosdb sql database list --account-name $CosmosName --resource-group $ResourceGroup -o table
} catch {
    Write-Warning ("Failed to query CosmosDB account {0}: {1}" -f $CosmosName, $_)
}

# Identity / role quick checks
Write-Section "Quick identity and role hints"
try{
    # GraphQL backend identity
    $dabIdentity = az containerapp show --name $DabName --resource-group $ResourceGroup --query identity -o json | ConvertFrom-Json
    if ($null -ne $dabIdentity) {
        if ($dabIdentity.type -eq 'UserAssigned'){
            Write-Host "DAB uses User-assigned identity. PrincipalIds:"
            $dabIdentity.userAssignedIdentities.GetEnumerator() | ForEach-Object { Write-Host " - $($_.Key) -> principalId: $($_.Value.principalId)" }
        } else {
            Write-Host "DAB identity: $($dabIdentity.type)"
        }
    } else { Write-Host "No identity returned for DAB" }
} catch {
    Write-Warning "Failed to inspect DAB identity: $_"
}

# Summary
Write-Section "Summary (quick checks)"
Write-Host "GraphQL backend: $DabName (resource group: $ResourceGroup)"
Write-Host "Portal: $PortalName (resource group: $ResourceGroup)"
Write-Host "ACR: $AcrName"
Write-Host "Cosmos: $CosmosName"
Write-Host "TailLogs: $TailLogs"

Write-Host "`nDiagnostics complete. Review warnings and logs above for next steps."
Write-Host "If you want, re-run with '-TailLogs' to capture live logs, or open an issue with the pasted output."
