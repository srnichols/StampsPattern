# Redeploy Host (regional + cells) to apply HTTP->HTTPS redirect and DNS label changes
param(
  [string]$SubscriptionId = '2fb123ca-e419-4838-9b44-c2eb71a21769',
  [string]$ResourceGroup = 'rg-stamps-host',
  [string]$TemplateFile = 'AzureArchitecture/host-main.bicep',
  [string]$ParametersFile = 'AzureArchitecture/host-main.parameters.json',
  [string]$GlobalLawId = '/subscriptions/480cb033-9a92-4912-9d30-c6b7bf795a87/resourceGroups/rg-stamps-hub/providers/Microsoft.OperationalInsights/workspaces/law-stamps-hub-2rl64hudjvcpq',
  [string]$SqlAdminPassword = 'P@ssw0rd!Z9x8y7',
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
Write-Host "Setting subscription $SubscriptionId" -ForegroundColor Cyan
az account set --subscription $SubscriptionId | Out-Null

Write-Host "Building bicep template..." -ForegroundColor Cyan
az bicep build --file $TemplateFile | Out-Null

Write-Host "Validating template and parameters..." -ForegroundColor Cyan
az deployment group validate `
  --resource-group $ResourceGroup `
  --template-file $TemplateFile `
  --parameters @${ParametersFile} `
  --parameters globalLogAnalyticsWorkspaceId=$GlobalLawId `
               sqlAdminPassword=$SqlAdminPassword `
  -o table

if ($WhatIf) {
  Write-Host "What-if preview:" -ForegroundColor Yellow
  az deployment group what-if `
    --resource-group $ResourceGroup `
    --template-file $TemplateFile `
    --parameters @${ParametersFile} `
    --parameters globalLogAnalyticsWorkspaceId=$GlobalLawId `
                 sqlAdminPassword=$SqlAdminPassword `
    --no-pretty-print
  return
}

$ts = Get-Date -Format yyyyMMddHHmmss
Write-Host "Deploying host-stamps-$ts ..." -ForegroundColor Green
az deployment group create `
  --resource-group $ResourceGroup `
  --template-file $TemplateFile `
  --parameters @${ParametersFile} `
  --parameters globalLogAnalyticsWorkspaceId=$GlobalLawId `
               sqlAdminPassword=$SqlAdminPassword `
  --name host-stamps-$ts -o table

Write-Host "Deployment completed." -ForegroundColor Green
