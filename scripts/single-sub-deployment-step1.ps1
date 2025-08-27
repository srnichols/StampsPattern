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



# PowerShell script to deploy resourceGroups.bicep, then main.bicep, extract outputs for routing and management portal, and write to JSON files

# Set variables
$ResourceGroupsBicep = "./AzureArchitecture/resourceGroups.bicep"
$ResourceGroupsParams = "./AzureArchitecture/resourceGroups.parameters.json"
$BicepFile = "./AzureArchitecture/main.bicep"
$ParametersFile = "./AzureArchitecture/main.parameters.json"
$DeploymentName = "stamps-main-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$MgmtOutputFile = "./AzureArchitecture/management-portal.parameters.json"
$RoutingOutputFile = "./AzureArchitecture/routing.parameters.json"

# Set the subscription
az account set --subscription $SubscriptionId


# Deploy resourceGroups.bicep first (creates RGs and global identity)
Write-Host "\n[INFO] Deploying resource groups using resourceGroups.bicep..."
$rgDeployResult = & az deployment sub create `
    --name "stamps-rg-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    --location $Location `
    --template-file $ResourceGroupsBicep `
    --parameters @$ResourceGroupsParams `
    --query "properties.outputs" `
    --output json 2>&1
$rgExitCode = $LASTEXITCODE
if ($rgExitCode -ne 0 -or -not $rgDeployResult) {
    Write-Error "[ERROR] Resource group deployment failed with exit code $rgExitCode."
    Write-Host "[ERROR] Full output from az deployment sub create (resourceGroups.bicep):"
    Write-Host $rgDeployResult
    exit 1
}

# Parse outputs for global identity
try {
    $rgOutputs = $rgDeployResult | ConvertFrom-Json
    $globalIdentityResourceId = $rgOutputs.globalIdentityResourceId.value
    $globalIdentityPrincipalId = $rgOutputs.globalIdentityPrincipalId.value
    Write-Host "[INFO] Global identity resourceId: $globalIdentityResourceId"
    Write-Host "[INFO] Global identity principalId: $globalIdentityPrincipalId"
} catch {
    Write-Error "[ERROR] Failed to parse resourceGroups.bicep outputs for global identity. Raw output:"
    Write-Host $rgDeployResult
    exit 1
}

# Assign Contributor at subscription scope to the global identity
Write-Host "[INFO] Assigning Contributor role to global identity at subscription scope..."
$roleAssignResult = & az deployment sub create `
    --name "stamps-identity-role-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    --location $Location `
    --template-file "./AzureArchitecture/globalIdentityRoleAssignment.sub.bicep" `
    --parameters identityResourceId="$globalIdentityResourceId" principalId="$globalIdentityPrincipalId" `
    --output json 2>&1
if ($LASTEXITCODE -ne 0 -or -not $roleAssignResult) {
    Write-Error "[ERROR] Role assignment deployment failed."
    Write-Host $roleAssignResult
    exit 1
}
Write-Host "[INFO] Contributor role assigned to global identity. Waiting 30 seconds for propagation..."
Start-Sleep -Seconds 30


# Build parameters arguments, including global identity
$paramArgs = @("$ParametersFile")
if ($Salt -ne '') {
    $paramArgs += "salt=$Salt"
}
$paramArgs += "userAssignedIdentityResourceId=$globalIdentityResourceId"

# Deploy main.bicep at subscription scope and capture outputs with error handling
Write-Host "\n[INFO] Starting deployment: $DeploymentName"
$azCmd = @(
    'az deployment sub create',
    "--name '$DeploymentName'",
    "--location '$Location'",
    "--template-file '$BicepFile'",
    "--parameters $($paramArgs -join ' ')",
    '--query "properties.outputs"',
    '--output json'
)
$azCmdStr = $azCmd -join ' '
Write-Host "[DEBUG] Running: $azCmdStr"

try {
    $deploymentResult = & az deployment sub create `
        --name $DeploymentName `
        --location $Location `
        --template-file $BicepFile `
        --parameters $paramArgs `
        --query "properties.outputs" `
        --output json 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0 -or -not $deploymentResult) {
        Write-Error "[ERROR] Deployment command failed with exit code $exitCode."
        Write-Host "[ERROR] Full output from az deployment sub create:"
        Write-Host $deploymentResult
        exit 1
    }
} catch {
    Write-Error "[ERROR] Exception during deployment: $_"
    exit 1
}

# Parse outputs
try {
    $outputs = $deploymentResult | ConvertFrom-Json
} catch {
    Write-Error "[ERROR] Failed to parse deployment output as JSON. Raw output:"
    Write-Host $deploymentResult
    exit 1
}

# Extract management portal parameters
if ($outputs.managementPortalDeploymentParams -and $outputs.managementPortalDeploymentParams.value) {
    $mgmtParams = $outputs.managementPortalDeploymentParams.value
    $mgmtParams | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 $MgmtOutputFile
    Write-Host "[INFO] Management portal parameters written to $MgmtOutputFile"
} else {
    Write-Error "[ERROR] managementPortalDeploymentParams output not found in deployment outputs. Full outputs:"
    Write-Host ($outputs | ConvertTo-Json -Depth 5)
    exit 1
}

# Extract routing parameters (if present)
if ($outputs.globalLayerOutputs -and $outputs.globalLayerOutputs.value) {
    $routingParams = $outputs.globalLayerOutputs.value
    $routingParams | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 $RoutingOutputFile
    Write-Host "[INFO] Routing parameters written to $RoutingOutputFile"
} else {
    Write-Warning "[WARN] globalLayerOutputs not found in deployment outputs. Routing parameters file not written."
    Write-Host "[DEBUG] Full outputs:"
    Write-Host ($outputs | ConvertTo-Json -Depth 5)
}