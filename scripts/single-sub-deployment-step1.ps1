#!/usr/bin/env pwsh

# PowerShell script to deploy main.bicep, extract management portal outputs, and write to management-portal.parameters.json

# Set variables
$BicepFile = "./AzureArchitecture/main.bicep"
$ParametersFile = "./AzureArchitecture/main.parameters.json"
$DeploymentName = "stamps-main-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$OutputFile = "./AzureArchitecture/management-portal.parameters.json"

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

# Parse outputs and extract managementPortalDeploymentParams
$outputs = $deploymentResult | ConvertFrom-Json
$mgmtParams = $outputs.managementPortalDeploymentParams.value

if (-not $mgmtParams) {
    Write-Error "managementPortalDeploymentParams output not found."
    exit 1
}

# Write management portal parameters to JSON file
$mgmtParams | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 $OutputFile
Write-Host "Management portal parameters written to $OutputFile"
