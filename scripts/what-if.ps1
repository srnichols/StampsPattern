param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('smoke','dev','prod')]
    [string]$Profile = 'smoke',

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = 'rg-stamps-smoke',

    [Parameter(Mandatory = $false)]
    [string]$Location = 'eastus'
)

$ErrorActionPreference = 'Stop'

# Resolve repository root (script folder is <repo>/scripts)
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

Write-Host "Using profile: $Profile" -ForegroundColor Cyan
Write-Host "Template: $templatePath" -ForegroundColor DarkGray
Write-Host "Parameters: $paramsPath" -ForegroundColor DarkGray
Write-Host "Resource Group: $ResourceGroup | Location: $Location" -ForegroundColor DarkGray

# Ensure resource group exists
az group create --name $ResourceGroup --location $Location | Out-Null

# Build common args
$whatIfArgs = @('deployment','group','what-if','--resource-group',$ResourceGroup,'--template-file',$templatePath,'--parameters',"@$paramsPath",'--result-format','ResourceIdOnly','--no-pretty-print')

if ($SubscriptionId) {
    $whatIfArgs += @('--subscription', $SubscriptionId)
}

Write-Host "Running what-if..." -ForegroundColor Yellow
az @whatIfArgs
