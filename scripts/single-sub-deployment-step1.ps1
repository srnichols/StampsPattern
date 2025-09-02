#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    [Parameter(Mandatory=$true)]
    [string]$Location,
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    [Parameter(Mandatory=$false)]
    [string]$Salt = '',
    [Parameter(Mandatory=$false)]
    [switch]$AutoRunApimSync = $false
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

Start-Sleep -Seconds 15
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
// Conditional: run apim-sync.ps1 for non-prod multi-APIM demo deployments
Write-Host "[INFO] Evaluating whether to run apim-sync.ps1..."
try {
    $aggregatedApim = $null
    if ($outputs.aggregatedApimGatewayUrls -and $outputs.aggregatedApimGatewayUrls.value) {
        $aggregatedApim = $outputs.aggregatedApimGatewayUrls.value
    } elseif ($outputs.apimGatewayUrls -and $outputs.apimGatewayUrls.value) {
        # Fallback: older templates may expose apimGatewayUrls directly
        $aggregatedApim = $outputs.apimGatewayUrls.value
    }

    if ($null -ne $aggregatedApim) {
        Write-Host "[DEBUG] Aggregated APIM gateway URLs: $($aggregatedApim | ConvertTo-Json -Depth 2)"
    } else {
        Write-Host "[DEBUG] No aggregated APIM gateway URLs found in outputs. apim-sync will be skipped."
    }

    # Only run the sync if explicitly requested, non-prod, and there are multiple APIM gateway URLs
    if ($AutoRunApimSync -and $Environment -ne 'prod' -and $aggregatedApim -and $aggregatedApim.Count -gt 1) {
        Write-Host "[INFO] AutoRunApimSync enabled and non-prod multi-APIM deployment detected. Preparing to run apim-sync.ps1"

        # Require explicit apimResourceId output (do not attempt risky best-effort parsing)
        if (-not ($outputs.apimResourceId -and $outputs.apimResourceId.value)) {
            Write-Warning "[WARN] apimResourceId output not present. For safety, apim-sync will not run. Provide apimResourceId in outputs or run apim-sync manually."
        } else {
            $apimResId = $outputs.apimResourceId.value
            $segments = $apimResId -split '/' | Where-Object { $_ -ne '' }
            $rgIndex = [array]::IndexOf($segments, 'resourceGroups')
            $primaryRg = $null
            $primaryApimName = $null
            if ($rgIndex -ge 0 -and $rgIndex -lt ($segments.Length - 1)) {
                $primaryRg = $segments[$rgIndex + 1]
                $primaryApimName = $segments[-1]
            }

            if ($primaryApimName -and $primaryRg) {
                # Derive secondary names only from well-formed azure-api.net hostnames
                $secondaryNames = @()
                for ($i = 1; $i -lt $aggregatedApim.Count; $i++) {
                    $url = $aggregatedApim[$i]
                    if ($url -and ($url -match '^https?://')) {
                        $hostname = $url -replace '^https?://','' -replace '/.*$',''
                        if ($hostname -match '^(?<svc>[^.]+)\.azure-api\.net$') {
                            $secondaryNames += $Matches['svc']
                        } else {
                            Write-Warning "[WARN] Skipping secondary APIM URL with non-standard host: $hostname (custom domains are not auto-mapped)."
                        }
                    }
                }

                if ($secondaryNames.Count -gt 0) {
                    Write-Host "[INFO] Calling apim-sync.ps1: Primary=$primaryApimName RG=$primaryRg Secondaries=$($secondaryNames -join ',')"
                    pwsh ./scripts/apim-sync.ps1 -PrimaryApimName $primaryApimName -PrimaryRg $primaryRg -SecondaryApimNames $secondaryNames -SubscriptionId $SubscriptionId
                } else {
                    Write-Warning "[WARN] No auto-discoverable secondary APIM names found. Skipping apim-sync."
                }
            } else {
                Write-Warning "[WARN] Could not derive primary APIM name or resource group from apimResourceId. Skipping apim-sync."
            }
        }
    } else {
        Write-Host "[INFO] apim-sync not required or AutoRunApimSync not enabled. Skipping."
    }
} catch {
    Write-Warning "[WARN] Exception while evaluating/running apim-sync: $_"
}

Write-Host "[INFO] Deployment script completed successfully!"