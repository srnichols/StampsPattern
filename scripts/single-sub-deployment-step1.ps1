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
Write-Host "[INFO] Setting deployment variables..."
$ResourceGroupsBicep = "./AzureArchitecture/resourceGroups.bicep"
$ResourceGroupsParams = "./AzureArchitecture/resourceGroups.parameters.json"
$BicepFile = "./AzureArchitecture/main.bicep"
$ParametersFile = "./AzureArchitecture/main.parameters.json"
$DeploymentName = "stamps-main-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$MgmtOutputFile = "./AzureArchitecture/management-portal.parameters.json"
$RoutingOutputFile = "./AzureArchitecture/routing.parameters.json"
Write-Host "[INFO] Deployment name: $DeploymentName"
Write-Host "[INFO] ResourceGroups Bicep: $ResourceGroupsBicep"
Write-Host "[INFO] Main Bicep: $BicepFile"
Write-Host "[INFO] Parameters file: $ParametersFile"

# Set the subscription
Write-Host "[INFO] Setting subscription to: $SubscriptionId"
az account set --subscription $SubscriptionId
Write-Host "[INFO] Subscription set successfully"


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
Write-Host "[INFO] Building deployment parameters..."
$paramArgs = @("$ParametersFile")
if ($Salt -ne '') {
    Write-Host "[INFO] Using salt: $Salt"
    $paramArgs += "salt=$Salt"
}
$paramArgs += "userAssignedIdentityResourceId=$globalIdentityResourceId"
Write-Host "[INFO] Parameters: $($paramArgs -join ', ')"

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
Write-Host "[INFO] Parsing deployment outputs..."
try {
    $outputs = $deploymentResult | ConvertFrom-Json
    Write-Host "[INFO] Deployment outputs parsed successfully"
} catch {
    Write-Error "[ERROR] Failed to parse deployment output as JSON. Raw output:"
    Write-Host $deploymentResult
    exit 1
}


# Extract management portal parameters
Write-Host "[INFO] Extracting management portal parameters..."
if ($outputs.managementPortalDeploymentParams -and $outputs.managementPortalDeploymentParams.value) {
    $mgmtParams = $outputs.managementPortalDeploymentParams.value
    Write-Host "[INFO] Writing management portal parameters to $MgmtOutputFile..."
    $mgmtParams | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 $MgmtOutputFile
    Write-Host "[INFO] Management portal parameters written to $MgmtOutputFile"
} else {
    Write-Error "[ERROR] managementPortalDeploymentParams output not found in deployment outputs. Full outputs:"
    Write-Host ($outputs | ConvertTo-Json -Depth 5)
    exit 1
}

# Extract routing parameters (if present)
Write-Host "[INFO] Extracting routing parameters..."
if ($outputs.globalLayerOutputs -and $outputs.globalLayerOutputs.value) {
    $routingParams = $outputs.globalLayerOutputs.value
    Write-Host "[INFO] Writing routing parameters to $RoutingOutputFile..."
    $routingParams | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 $RoutingOutputFile
    Write-Host "[INFO] Routing parameters written to $RoutingOutputFile"
} else {
    Write-Warning "[WARN] globalLayerOutputs not found in deployment outputs. Routing parameters file not written."
    Write-Host "[DEBUG] Full outputs:"
    Write-Host ($outputs | ConvertTo-Json -Depth 5)
}

# Post-deployment: Assign Key Vault access policy to SQL Server managed identity
Write-Host "[INFO] Starting post-deployment tasks..."
if ($outputs.sqlServerSystemAssignedPrincipalId -and $outputs.sqlServerSystemAssignedPrincipalId.value -and $outputs.keyVaultName -and $outputs.keyVaultName.value) {
    $sqlPrincipalId = $outputs.sqlServerSystemAssignedPrincipalId.value
    $keyVaultName = $outputs.keyVaultName.value
    Write-Host "[INFO] Found SQL Server principal ID: $sqlPrincipalId"
    Write-Host "[INFO] Found Key Vault name: $keyVaultName"
    Write-Host "[INFO] Assigning Key Vault access policy to SQL Server managed identity..."
    $setPolicyResult = & az keyvault set-policy --name $keyVaultName --object-id $sqlPrincipalId --secret-permissions get --key-permissions get wrapKey unwrapKey 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $setPolicyResult) {
        Write-Error "[ERROR] Failed to assign Key Vault access policy to SQL Server managed identity."
        Write-Host $setPolicyResult
        exit 1
    } else {
        Write-Host "[INFO] Key Vault access policy assigned to SQL Server managed identity."
    }
} else {
    Write-Warning "[WARN] Could not find SQL Server principalId or Key Vault name in outputs. Skipping post-deployment Key Vault policy assignment."
}
Write-Host "[INFO] Deployment script completed successfully!"