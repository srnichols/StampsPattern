#!/usr/bin/env pwsh


# PowerShell script to deploy main.bicep, extract outputs for routing and management portal, and write to JSON files

# Set variables
$BicepFile = "./AzureArchitecture/main.bicep"
$ParametersFile = "./AzureArchitecture/main.parameters.json"
$DeploymentName = "stamps-main-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$MgmtOutputFile = "./AzureArchitecture/management-portal.parameters.json"
$RoutingOutputFile = "./AzureArchitecture/routing.parameters.json"

# Deploy main.bicep at subscription scope and capture outputs
$deploymentResult = az deployment sub create `
    --name $DeploymentName `
    --location westus2 `
    --template-file $BicepFile `
    --parameters @$ParametersFile `
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
