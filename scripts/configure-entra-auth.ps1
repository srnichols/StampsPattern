param(
    [Parameter(Mandatory = $true)] [string] $ResourceGroup,
    [Parameter(Mandatory = $true)] [string] $ContainerAppName,
    [Parameter(Mandatory = $true)] [string] $TenantId,
    [string] $DisplayNamePrefix = "stamps-portal"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-AzCliJson {
    param([Parameter(Mandatory=$true)][string]$Command)
    $json = Invoke-Expression $Command
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $Command" }
    return $json | ConvertFrom-Json
}

Write-Host "Resolving Container App FQDN..."
$fqdn = az containerapp show --name $ContainerAppName --resource-group $ResourceGroup --query "properties.configuration.ingress.fqdn" -o tsv
if (-not $fqdn) { throw "Container App FQDN not found. Ensure the app exists and ingress is enabled." }
$baseUrl = "https://$fqdn"
$redirectUri = "$baseUrl/signin-oidc"
Write-Host "Using redirect URI: $redirectUri"

$timestamp = Get-Date -Format 'yyyyMMddHHmmss'
$appDisplayName = "$DisplayNamePrefix-$timestamp"

Write-Host "Creating Entra ID app registration: $appDisplayName"
$appCreateOut = az ad app create --display-name $appDisplayName --sign-in-audience AzureADMyOrg --web-redirect-uris $redirectUri -o json
if ($LASTEXITCODE -ne 0 -or -not $appCreateOut) { throw "Failed to create app registration." }
$app = $appCreateOut | ConvertFrom-Json
$appId = $app.appId
if (-not $appId) { throw "AppId missing from creation output." }

Write-Host "Enabling ID tokens on the app..."
az ad app update --id $appId --enable-id-token-issuance true 1>$null
if ($LASTEXITCODE -ne 0) { throw "Failed to enable ID token issuance." }

Write-Host "Creating client secret..."
function New-ClientSecretWithPolicyFallback {
    param([string]$AppId, [string]$DisplayName)
    $durations = @(180, 90, 30) # days
    foreach ($days in $durations) {
        $endDate = (Get-Date).AddDays($days).ToString('yyyy-MM-dd')
        Write-Host "Trying to create secret with end-date: $endDate ($days days)"
        $secret = az ad app credential reset --id $AppId --display-name $DisplayName --append --end-date $endDate --query password -o tsv 2>$null
        if ($LASTEXITCODE -eq 0 -and $secret) { return $secret }
        Write-Warning "Secret creation failed for $days days. Trying shorter duration..."
    }
    throw "Failed to create client secret within tenant policy limits."
}

$clientSecret = New-ClientSecretWithPolicyFallback -AppId $appId -DisplayName "portal-secret-$timestamp"

Write-Host "Updating Container App secret..."
az containerapp secret set --name $ContainerAppName --resource-group $ResourceGroup --secrets azuread-client-secret=$clientSecret 1>$null
if ($LASTEXITCODE -ne 0) { throw "Failed to set container app secret." }

Write-Host "Updating Container App env vars..."
az containerapp update --name $ContainerAppName --resource-group $ResourceGroup --set-env-vars `
    AzureAd__Instance=https://login.microsoftonline.com/ `
    AzureAd__TenantId=$TenantId `
    AzureAd__ClientId=$appId `
    AzureAd__ClientSecret=secretref:azuread-client-secret `
    ASPNETCORE_FORWARDEDHEADERS_ENABLED=true 1>$null
if ($LASTEXITCODE -ne 0) { throw "Failed to update container app env vars." }

Write-Host "Done. AppId: $appId"
Write-Host "Sign-in URL: $baseUrl"