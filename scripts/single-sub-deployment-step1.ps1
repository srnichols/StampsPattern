#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    [Parameter(Mandatory=$true)]
    [string]$Location,
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    [Parameter(Mandatory=$false)]
    [string]$Salt = ''
)


# PowerShell script to deploy main.bicep, extract outputs for routing and management portal, and write to JSON files

# Set variables
$BicepFile = "./AzureArchitecture/main.bicep"
$ParametersFile = "./AzureArchitecture/main.parameters.json"
$DeploymentName = "stamps-main-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$MgmtOutputFile = "./AzureArchitecture/management-portal.parameters.json"
$RoutingOutputFile = "./AzureArchitecture/routing.parameters.json"

# Set the subscription
az account set --subscription $SubscriptionId



# Build parameters arguments
$paramArgs = @("$ParametersFile")
if ($Salt -ne '') {
    $paramArgs += "salt=$Salt"
}

# Deploy main.bicep at subscription scope and capture outputs
$deploymentResult = az deployment sub create `
    --name $DeploymentName `
    --location $Location `
    --template-file $BicepFile `
    --parameters $paramArgs `
    --query "properties.outputs" `
    --output json

if (-not $deploymentResult) {
    Write-Error "Deployment failed or no outputs returned."
    exit 1
}

# Parse outputs
$outputs = $deploymentResult | ConvertFrom-Json

# Extract management portal parameters
$mgmtParams = $outputs.managementPortalDeploymentParams.value
if (-not $mgmtParams) {
    Write-Error "managementPortalDeploymentParams output not found."
    exit 1
}
$mgmtParams | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 $MgmtOutputFile
Write-Host "Management portal parameters written to $MgmtOutputFile"

# Extract routing parameters (if present)
if ($outputs.globalLayerOutputs) {
    $routingParams = $outputs.globalLayerOutputs.value
    $routingParams | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 $RoutingOutputFile
    Write-Host "Routing parameters written to $RoutingOutputFile"
} else {
    Write-Warning "globalLayerOutputs not found in deployment outputs. Routing parameters file not written."
}