# Infrastructure Discovery Function - Production Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying the Infrastructure Discovery Function to production environments, including Azure Functions, configuration management, monitoring setup, and operational best practices.

## Prerequisites

### Required Azure Resources
- Azure Functions App (Premium or Dedicated plan recommended)
- Application Insights for monitoring and logging
- Azure Key Vault for secret management
- Managed Identity for secure authentication
- Azure Redis Cache (optional, for distributed caching)
- Azure Storage Account (for function app storage)

### Required Permissions
- **Reader** role on all subscriptions containing stamp infrastructure
- **Key Vault Secrets User** role on the Key Vault
- **Application Insights Component Contributor** for telemetry
- **Storage Account Contributor** for function storage

## Deployment Methods

### Method 1: Azure CLI Deployment

#### 1. Create Resource Group
```bash
# Set variables
RESOURCE_GROUP="rg-stamps-functions"
LOCATION="eastus"
FUNCTION_APP_NAME="func-stamps-discovery"
STORAGE_ACCOUNT="ststampsfunc$(date +%s)"
KEY_VAULT_NAME="kv-stamps-$(date +%s)"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION
```

#### 2. Create Supporting Resources
```bash
# Create storage account
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS

# Create Key Vault
az keyvault create \
  --name $KEY_VAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku standard

# Create Application Insights
az monitor app-insights component create \
  --app stamps-discovery-insights \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

#### 3. Create Function App
```bash
# Create Function App with managed identity
az functionapp create \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --storage-account $STORAGE_ACCOUNT \
  --runtime dotnet \
  --runtime-version 6 \
  --plan Premium \
  --assign-identity \
  --app-insights stamps-discovery-insights
```

#### 4. Configure Application Settings
```bash
# Get managed identity principal ID
PRINCIPAL_ID=$(az functionapp identity show \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query principalId -o tsv)

# Grant Key Vault access
az keyvault set-policy \
  --name $KEY_VAULT_NAME \
  --object-id $PRINCIPAL_ID \
  --secret-permissions get list

# Set application settings
az functionapp config appsettings set \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    "KeyVaultUrl=https://$KEY_VAULT_NAME.vault.azure.net/" \
    "ENABLE_ORYX_BUILD=true" \
    "SCM_DO_BUILD_DURING_DEPLOYMENT=true"
```

### Method 2: ARM Template Deployment

#### 1. ARM Template (azuredeploy.json)
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "functionAppName": {
      "type": "string",
      "metadata": {
        "description": "Name of the Azure Function App"
      }
    },
    "location": {
      "type": "string",
      "defaultValue": "[resourceGroup().location]",
      "metadata": {
        "description": "Location for all resources"
      }
    }
  },
  "variables": {
    "storageAccountName": "[concat('ststamps', uniqueString(resourceGroup().id))]",
    "keyVaultName": "[concat('kv-stamps-', uniqueString(resourceGroup().id))]",
    "appInsightsName": "[concat(parameters('functionAppName'), '-insights')]"
  },
  "resources": [
    {
      "type": "Microsoft.Storage/storageAccounts",
      "apiVersion": "2021-06-01",
      "name": "[variables('storageAccountName')]",
      "location": "[parameters('location')]",
      "sku": {
        "name": "Standard_LRS"
      },
      "kind": "StorageV2"
    },
    {
      "type": "Microsoft.KeyVault/vaults",
      "apiVersion": "2021-10-01",
      "name": "[variables('keyVaultName')]",
      "location": "[parameters('location')]",
      "properties": {
        "sku": {
          "family": "A",
          "name": "standard"
        },
        "tenantId": "[subscription().tenantId]",
        "accessPolicies": []
      }
    },
    {
      "type": "Microsoft.Insights/components",
      "apiVersion": "2020-02-02",
      "name": "[variables('appInsightsName')]",
      "location": "[parameters('location')]",
      "kind": "web",
      "properties": {
        "Application_Type": "web"
      }
    },
    {
      "type": "Microsoft.Web/serverfarms",
      "apiVersion": "2021-02-01",
      "name": "[concat(parameters('functionAppName'), '-plan')]",
      "location": "[parameters('location')]",
      "sku": {
        "name": "EP1",
        "tier": "ElasticPremium"
      },
      "kind": "elastic"
    },
    {
      "type": "Microsoft.Web/sites",
      "apiVersion": "2021-02-01",
      "name": "[parameters('functionAppName')]",
      "location": "[parameters('location')]",
      "kind": "functionapp",
      "identity": {
        "type": "SystemAssigned"
      },
      "dependsOn": [
        "[resourceId('Microsoft.Web/serverfarms', concat(parameters('functionAppName'), '-plan'))]",
        "[resourceId('Microsoft.Storage/storageAccounts', variables('storageAccountName'))]",
        "[resourceId('Microsoft.Insights/components', variables('appInsightsName'))]"
      ],
      "properties": {
        "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', concat(parameters('functionAppName'), '-plan'))]",
        "siteConfig": {
          "appSettings": [
            {
              "name": "AzureWebJobsStorage",
              "value": "[concat('DefaultEndpointsProtocol=https;AccountName=', variables('storageAccountName'), ';EndpointSuffix=', environment().suffixes.storage, ';AccountKey=',listKeys(resourceId('Microsoft.Storage/storageAccounts', variables('storageAccountName')), '2021-06-01').keys[0].value)]"
            },
            {
              "name": "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING",
              "value": "[concat('DefaultEndpointsProtocol=https;AccountName=', variables('storageAccountName'), ';EndpointSuffix=', environment().suffixes.storage, ';AccountKey=',listKeys(resourceId('Microsoft.Storage/storageAccounts', variables('storageAccountName')), '2021-06-01').keys[0].value)]"
            },
            {
              "name": "WEBSITE_CONTENTSHARE",
              "value": "[toLower(parameters('functionAppName'))]"
            },
            {
              "name": "FUNCTIONS_EXTENSION_VERSION",
              "value": "~4"
            },
            {
              "name": "FUNCTIONS_WORKER_RUNTIME",
              "value": "dotnet"
            },
            {
              "name": "APPINSIGHTS_INSTRUMENTATIONKEY",
              "value": "[reference(resourceId('Microsoft.Insights/components', variables('appInsightsName'))).InstrumentationKey]"
            },
            {
              "name": "KeyVaultUrl",
              "value": "[concat('https://', variables('keyVaultName'), '.vault.azure.net/')]"
            }
          ]
        }
      }
    }
  ]
}
```

#### 2. Deploy ARM Template
```bash
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file azuredeploy.json \
  --parameters functionAppName=$FUNCTION_APP_NAME
```

### Method 3: Bicep Deployment

#### 1. Bicep Template (main.bicep)
```bicep
@description('Name of the Azure Function App')
param functionAppName string

@description('Location for all resources')
param location string = resourceGroup().location

var storageAccountName = 'ststamps${uniqueString(resourceGroup().id)}'
var keyVaultName = 'kv-stamps-${uniqueString(resourceGroup().id)}'
var appInsightsName = '${functionAppName}-insights'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: '${functionAppName}-plan'
  location: location
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
  }
  kind: 'elastic'
}

resource functionApp 'Microsoft.Web/sites@2021-02-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'KeyVaultUrl'
          value: 'https://${keyVault.name}.vault.azure.net/'
        }
      ]
    }
  }
}
```

## Application Configuration

### Required Application Settings

| Setting | Description | Example |
|---------|-------------|---------|
| `KeyVaultUrl` | URL to Azure Key Vault | `https://kv-stamps-xyz.vault.azure.net/` |
| `APPINSIGHTS_INSTRUMENTATIONKEY` | Application Insights key | Auto-configured |
| `ENABLE_CACHE` | Enable/disable result caching | `true` |
| `CACHE_DURATION_MINUTES` | Cache duration in minutes | `5` |
| `MAX_PARALLEL_DISCOVERIES` | Max parallel resource discoveries | `10` |
| `DISCOVERY_TIMEOUT_SECONDS` | Discovery operation timeout | `300` |

### Key Vault Secrets

Store sensitive configuration in Azure Key Vault:

```bash
# Add secrets to Key Vault
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "CosmosConnectionString" \
  --value "AccountEndpoint=https://..."

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "RedisConnectionString" \
  --value "redisname.redis.cache.windows.net:6380,password=..."
```

### Function App Configuration

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "DefaultEndpointsProtocol=https;AccountName=...",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet",
    "FUNCTIONS_EXTENSION_VERSION": "~4",
    "APPINSIGHTS_INSTRUMENTATIONKEY": "12345678-1234-1234-1234-123456789012",
    "KeyVaultUrl": "https://kv-stamps-xyz.vault.azure.net/",
    "ENABLE_CACHE": "true",
    "CACHE_DURATION_MINUTES": "5",
    "MAX_PARALLEL_DISCOVERIES": "10",
    "DISCOVERY_TIMEOUT_SECONDS": "300"
  }
}
```

## Code Deployment

### Method 1: Azure DevOps Pipeline

#### azure-pipelines.yml
```yaml
trigger:
- main

pool:
  vmImage: 'windows-latest'

variables:
  buildConfiguration: 'Release'
  functionAppName: 'func-stamps-discovery'
  resourceGroupName: 'rg-stamps-functions'

stages:
- stage: Build
  jobs:
  - job: Build
    steps:
    - task: DotNetCoreCLI@2
      displayName: 'Restore packages'
      inputs:
        command: 'restore'
        projects: '**/*.csproj'

    - task: DotNetCoreCLI@2
      displayName: 'Build project'
      inputs:
        command: 'build'
        projects: '**/*.csproj'
        arguments: '--configuration $(buildConfiguration)'

    - task: DotNetCoreCLI@2
      displayName: 'Publish project'
      inputs:
        command: 'publish'
        projects: '**/*.csproj'
        arguments: '--configuration $(buildConfiguration) --output $(Build.ArtifactStagingDirectory)'
        zipAfterPublish: true

    - task: PublishBuildArtifacts@1
      displayName: 'Publish artifacts'
      inputs:
        pathToPublish: '$(Build.ArtifactStagingDirectory)'
        artifactName: 'FunctionApp'

- stage: Deploy
  dependsOn: Build
  jobs:
  - deployment: DeployFunctionApp
    environment: 'production'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: AzureFunctionApp@1
            displayName: 'Deploy Azure Function App'
            inputs:
              azureSubscription: 'Azure Service Connection'
              appType: 'functionApp'
              appName: '$(functionAppName)'
              package: '$(Pipeline.Workspace)/FunctionApp/*.zip'
```

### Method 2: GitHub Actions

#### .github/workflows/deploy.yml
```yaml
name: Deploy Function App

on:
  push:
    branches: [ main ]
  workflow_dispatch:

env:
  AZURE_FUNCTIONAPP_NAME: func-stamps-discovery
  AZURE_FUNCTIONAPP_PACKAGE_PATH: './AzureArchitecture'
  DOTNET_VERSION: '6.0.x'

jobs:
  build-and-deploy:
    runs-on: windows-latest
    steps:
    - name: 'Checkout GitHub Action'
      uses: actions/checkout@v3

    - name: Setup DotNet ${{ env.DOTNET_VERSION }} Environment
      uses: actions/setup-dotnet@v3
      with:
        dotnet-version: ${{ env.DOTNET_VERSION }}

    - name: 'Resolve Project Dependencies Using Dotnet'
      shell: pwsh
      run: |
        pushd './${{ env.AZURE_FUNCTIONAPP_PACKAGE_PATH }}'
        dotnet build --configuration Release --output ./output
        popd

    - name: 'Run Azure Functions Action'
      uses: Azure/functions-action@v1
      with:
        app-name: ${{ env.AZURE_FUNCTIONAPP_NAME }}
        package: '${{ env.AZURE_FUNCTIONAPP_PACKAGE_PATH }}/output'
        publish-profile: ${{ secrets.AZURE_FUNCTIONAPP_PUBLISH_PROFILE }}
```

### Method 3: Azure CLI Deployment

```bash
# Build and package the function
dotnet build --configuration Release
dotnet publish --configuration Release --output ./publish

# Create deployment package
cd publish
zip -r ../function-app.zip .
cd ..

# Deploy to Azure Functions
az functionapp deployment source config-zip \
  --resource-group $RESOURCE_GROUP \
  --name $FUNCTION_APP_NAME \
  --src function-app.zip
```

## Security Configuration

### Managed Identity Setup

```bash
# Enable system-assigned managed identity
az functionapp identity assign \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP

# Get the principal ID
PRINCIPAL_ID=$(az functionapp identity show \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query principalId -o tsv)

# Grant Reader access to subscription
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Reader" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

### Network Security

```bash
# Configure VNET integration
az functionapp vnet-integration add \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --subnet "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VNET_RG/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$SUBNET_NAME"

# Configure private endpoints
az network private-endpoint create \
  --name "${FUNCTION_APP_NAME}-pe" \
  --resource-group $RESOURCE_GROUP \
  --subnet $SUBNET_ID \
  --private-connection-resource-id $FUNCTION_APP_ID \
  --group-id sites \
  --connection-name "${FUNCTION_APP_NAME}-connection"
```

## Monitoring and Logging

### Application Insights Configuration

```bash
# Enable detailed monitoring
az functionapp config appsettings set \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    "APPINSIGHTS_INSTRUMENTATIONKEY=$APPINSIGHTS_KEY" \
    "APPLICATIONINSIGHTS_CONNECTION_STRING=$APPINSIGHTS_CONNECTION" \
    "ApplicationInsightsAgent_EXTENSION_VERSION=~2" \
    "XDT_MicrosoftApplicationInsights_Mode=recommended"
```

### Log Analytics Queries

```kusto
// Function execution performance
requests
| where name == "DiscoverInfrastructure"
| summarize 
    AvgDuration = avg(duration),
    P95Duration = percentile(duration, 95),
    RequestCount = count()
by bin(timestamp, 5m)
| render timechart

// Error analysis
exceptions
| where operation_Name == "DiscoverInfrastructure"
| summarize ErrorCount = count() by type, bin(timestamp, 1h)
| render columnchart

// Cache hit rates
traces
| where message contains "Cache hit" or message contains "Cache miss"
| extend CacheStatus = case(
    message contains "Cache hit", "Hit",
    message contains "Cache miss", "Miss",
    "Unknown"
)
| summarize HitRate = countif(CacheStatus == "Hit") * 100.0 / count()
by bin(timestamp, 15m)
| render linechart
```

### Alerts Configuration

```bash
# Create action group
az monitor action-group create \
  --name "stamps-alerts" \
  --resource-group $RESOURCE_GROUP \
  --short-name "StampsAlerts"

# Create alert rule for high error rate
az monitor metrics alert create \
  --name "HighErrorRate" \
  --resource-group $RESOURCE_GROUP \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$FUNCTION_APP_NAME" \
  --condition "avg requests/failed > 5" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action "stamps-alerts"
```

## Performance Optimization

### Function App Scaling

```bash
# Configure elastic premium plan scaling
az functionapp plan update \
  --name "${FUNCTION_APP_NAME}-plan" \
  --resource-group $RESOURCE_GROUP \
  --max-burst 20 \
  --sku EP2
```

### Caching Configuration

```json
{
  "host": {
    "version": "2.0",
    "extensionBundle": {
      "id": "Microsoft.Azure.Functions.ExtensionBundle",
      "version": "[2.*, 3.0.0)"
    },
    "functionTimeout": "00:05:00",
    "extensions": {
      "http": {
        "routePrefix": "api",
        "maxOutstandingRequests": 200,
        "maxConcurrentRequests": 100
      }
    }
  }
}
```

## Disaster Recovery

### Backup Strategy

```bash
# Export function app configuration
az functionapp config backup create \
  --resource-group $RESOURCE_GROUP \
  --name $FUNCTION_APP_NAME \
  --backup-name "weekly-backup-$(date +%Y%m%d)"

# Backup source code
git clone https://github.com/your-org/stamps-pattern.git
cd stamps-pattern
git archive --format=zip --output=function-backup-$(date +%Y%m%d).zip HEAD
```

### Multi-Region Deployment

```bash
# Deploy to secondary region
SECONDARY_REGION="westus2"
SECONDARY_RG="rg-stamps-functions-dr"

# Create secondary deployment
az group create --name $SECONDARY_RG --location $SECONDARY_REGION

# Deploy ARM template to secondary region
az deployment group create \
  --resource-group $SECONDARY_RG \
  --template-file azuredeploy.json \
  --parameters functionAppName="${FUNCTION_APP_NAME}-dr" location=$SECONDARY_REGION
```

## Operational Procedures

### Health Checks

```bash
# Function health check
curl -X GET "https://${FUNCTION_APP_NAME}.azurewebsites.net/api/infrastructure/discover?mode=simulated"

# Detailed health endpoint
curl -X GET "https://${FUNCTION_APP_NAME}.azurewebsites.net/admin/host/status"
```

### Performance Testing

```powershell
# Load testing script
$endpoint = "https://${env:FUNCTION_APP_NAME}.azurewebsites.net/api/infrastructure/discover"
$jobs = 1..50 | ForEach-Object {
    Start-Job -ScriptBlock {
        param($url)
        Measure-Command {
            Invoke-RestMethod -Uri $url -Method GET
        }
    } -ArgumentList $endpoint
}

$results = $jobs | Wait-Job | Receive-Job
$averageTime = ($results | Measure-Object -Property TotalMilliseconds -Average).Average
Write-Host "Average response time: $averageTime ms"
```

### Troubleshooting

#### Common Issues

1. **Authentication Failures**
   ```bash
   # Check managed identity status
   az functionapp identity show --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP
   
   # Verify role assignments
   az role assignment list --assignee $PRINCIPAL_ID
   ```

2. **Performance Issues**
   ```kusto
   // Check function execution duration
   requests
   | where name == "DiscoverInfrastructure"
   | where duration > 10000  // Over 10 seconds
   | project timestamp, duration, resultCode
   | order by timestamp desc
   ```

3. **Memory Issues**
   ```kusto
   // Monitor memory usage
   performanceCounters
   | where category == "Memory"
   | where counter == "Available Bytes"
   | render timechart
   ```

### Maintenance Windows

```bash
# Schedule maintenance deployment
az functionapp deployment slot create \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --slot staging

# Deploy to staging slot
az functionapp deployment source config-zip \
  --resource-group $RESOURCE_GROUP \
  --name $FUNCTION_APP_NAME \
  --src function-app.zip \
  --slot staging

# Validate staging deployment
curl -X GET "https://${FUNCTION_APP_NAME}-staging.azurewebsites.net/api/infrastructure/discover"

# Swap slots
az functionapp deployment slot swap \
  --resource-group $RESOURCE_GROUP \
  --name $FUNCTION_APP_NAME \
  --slot staging \
  --target-slot production
```

## Cost Optimization

### Resource Right-Sizing

```bash
# Monitor function execution metrics
az monitor metrics list \
  --resource "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$FUNCTION_APP_NAME" \
  --metric "FunctionExecutionCount,FunctionExecutionUnits" \
  --start-time "2024-01-01T00:00:00Z" \
  --end-time "2024-01-31T23:59:59Z"
```

### Billing Analysis

```kusto
// Function execution costs
requests
| where name == "DiscoverInfrastructure"
| summarize 
    ExecutionCount = count(),
    TotalDurationMs = sum(duration)
| extend 
    ExecutionUnits = TotalDurationMs / 1000.0,
    EstimatedCost = ExecutionUnits * 0.000016  // Azure Functions pricing
```

## Support and Maintenance

### Documentation Updates
- Update this guide with deployment lessons learned
- Document custom configuration requirements
- Maintain troubleshooting runbooks

### Team Access
- Grant deployment permissions to DevOps team
- Configure monitoring access for operations team
- Set up on-call procedures for critical alerts

### Regular Tasks
- Monthly security patch updates
- Quarterly performance optimization reviews
- Annual disaster recovery testing
- Regular backup verification

This production deployment guide ensures reliable, secure, and scalable deployment of the Infrastructure Discovery Function in enterprise Azure environments.
