# Helper: Filter out endpoints with empty/null FQDNs
function Filter-ValidEndpoints {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Endpoints
    )
    return $Endpoints | Where-Object { $_.fqdn -and $_.fqdn.Trim() -ne '' }
}

# PowerShell script to deploy main.bicep, extract management portal outputs, and write to management-portal.parameters.json

# Set variables
$BicepFile = "./AzureArchitecture/host-main.bicep"
$ParametersFile = "./AzureArchitecture/host-main.parameters.json"
$DeploymentName = "stamps-host-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$OutputFile = "./AzureArchitecture/management-portal.parameters.json"


# (Optional) If you have a regionalEndpoints array to pass, filter it here before deployment
# Example usage:
# $regionalEndpoints = ... # Load or construct your endpoints array
# $filteredEndpoints = Filter-ValidEndpoints -Endpoints $regionalEndpoints
# Then pass $filteredEndpoints to Bicep as a parameter

# Deploy host-main.bicep at subscription scope and capture outputs
$deploymentResult = az deployment sub create `
    --name $DeploymentName `
    --location westus3 `
    --template-file $BicepFile `
    --parameters @$ParametersFile `
    --query "properties.outputs" `
    --output json

if (-not $deploymentResult) {
    Write-Error "Deployment failed or no outputs returned."
    exit 1
}

# Parse outputs and check if deployment succeeded
if (-not $deploymentResult) {
    Write-Error "Deployment failed or no outputs returned."
    exit 1
}

$outputs = $deploymentResult | ConvertFrom-Json
Write-Host "Deployment completed successfully!"
Write-Host "Outputs received:"
$outputs | ConvertTo-Json -Depth 3

# Create basic management portal parameters (host-main.bicep may not have this specific output)
$mgmtParams = @{
    resourceGroupName = "rg-stamps-global-tst"
    location = "westus3"
    environment = "tst"
    subscriptionId = (az account show --query "id" --output tsv)
}

# Write management portal parameters to JSON file
$mgmtParams | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 $OutputFile
Write-Host "Management portal parameters written to $OutputFile"
