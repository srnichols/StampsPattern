#!/usr/bin/env pwsh

# PowerShell script to deploy routing resources using outputs from infra deployment
# Usage: pwsh ./scripts/deploy-routing.ps1 -ParametersFile ./AzureArchitecture/routing.parameters.json

param(
    [Parameter(Mandatory = $false)]
    [string]$ParametersFile = "./AzureArchitecture/routing.parameters.json"
)

$ErrorActionPreference = "Stop"

Write-Host "🚦 Starting Routing deployment..." -ForegroundColor Green

# Read parameters from JSON file
if (-not (Test-Path $ParametersFile)) {
    Write-Host "Parameters file not found: $ParametersFile" -ForegroundColor Red
    exit 1
}

$parametersContent = Get-Content $ParametersFile -Raw | ConvertFrom-Json

# Example: Extract required values (customize as needed)
$ResourceGroupName = $parametersContent.resourceGroupName
$Location = $parametersContent.location
$SubscriptionId = $parametersContent.subscriptionId
$EnvironmentName = $parametersContent.environment

Write-Host "📋 Using parameters:" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "  Location: $Location" -ForegroundColor White
Write-Host "  Subscription: $SubscriptionId" -ForegroundColor White
Write-Host "  Environment: $EnvironmentName" -ForegroundColor White


# Example: Deploy routing resources using a Bicep or ARM template (customize as needed)
Write-Host "Running routing deployment via az deployment group create..." -ForegroundColor Yellow
az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file ./AzureArchitecture/globalLayer.bicep `
    --parameters @$ParametersFile

Write-Host "✅ Routing deployment step complete." -ForegroundColor Green
