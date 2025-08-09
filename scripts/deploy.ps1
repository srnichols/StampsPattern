param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('smoke','dev','prod')]
    [string]$Profile = 'smoke',

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false)]
    [string]$Location = 'eastus',

    [switch]$VerboseOutput
)

$ErrorActionPreference = 'Stop'

# Default resource group by profile if not provided
if (-not $ResourceGroup) {
    $ResourceGroup = switch ($Profile) {
        'smoke' { 'rg-stamps-smoke' }
        'dev'   { 'rg-stamps-dev' }
        'prod'  { 'rg-stamps-prod' }
    }
}

# Resolve repository root
$repoRoot = Split-Path -Parent $PSScriptRoot
$templatePath = Join-Path $repoRoot 'AzureArchitecture/main.bicep'

$exampleRel = switch ($Profile) {
    'smoke' { 'AzureArchitecture/examples/main.sample.smoke.json' }
    'dev'   { 'AzureArchitecture/examples/main.sample.silver.json' }
    'prod'  { 'AzureArchitecture/examples/main.sample.platinum.json' }
}

$paramsPath = Join-Path $repoRoot $exampleRel

if (-not (Test-Path $templatePath)) {
    throw "Template not found: $templatePath"
}
if (-not (Test-Path $paramsPath)) {
    throw "Parameters file not found for profile '$Profile': $paramsPath"
}

Write-Host "Deploying profile: $Profile" -ForegroundColor Cyan
Write-Host "Template: $templatePath" -ForegroundColor DarkGray
Write-Host "Parameters: $paramsPath" -ForegroundColor DarkGray
Write-Host "Resource Group: $ResourceGroup | Location: $Location" -ForegroundColor DarkGray

# Ensure resource group exists
az group create --name $ResourceGroup --location $Location | Out-Null

$deployArgs = @('deployment','group','create',
    '--resource-group',$ResourceGroup,
    '--template-file',$templatePath,
    '--parameters',"@$paramsPath",
    '--verbose')

if ($SubscriptionId) {
    $deployArgs += @('--subscription', $SubscriptionId)
}

if (-not $VerboseOutput) {
    # Reduce noise by piping to Out-Null; errors still throw
    Write-Host "Starting deployment (this may take a while)..." -ForegroundColor Yellow
    az @deployArgs | Out-Null
} else {
    Write-Host "Starting deployment with verbose output..." -ForegroundColor Yellow
    az @deployArgs
}

Write-Host "Deployment completed." -ForegroundColor Green
