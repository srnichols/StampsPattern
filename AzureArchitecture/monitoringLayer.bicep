// --------------------------------------------------------------------------------------
// Module: monitoringLayer
// Purpose: Provisions monitoring resources such as Log Analytics Workspace for centralized logging and monitoring.
//          Outputs the workspace resource ID for integration with other modules.
// --------------------------------------------------------------------------------------


@description('Azure region for the monitoring resources')
param location string
@description('Name of the Log Analytics Workspace (must be globally unique)')
param logAnalyticsWorkspaceName string
@description('Retention period (in days) for logs')
param retentionInDays int
@description('Tags for resource management')
param tags object = {}

@description('Key Vault name to store the Log Analytics key')
param keyVaultName string
@description('Secret name for the Log Analytics key in Key Vault')
param logAnalyticsKeySecretName string = 'logAnalyticsWorkspaceKey'

@description('Resource ID of a user-assigned managed identity with access to Key Vault and Log Analytics')
param userAssignedIdentityResourceId string

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: '${logAnalyticsWorkspaceName}-${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  properties: {
    retentionInDays: retentionInDays
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}


resource storeLogAnalyticsKeyScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'store-loganalytics-key-script'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    azCliVersion: '2.53.0'
    timeout: 'PT10M'
    cleanupPreference: 'OnSuccess'
    forceUpdateTag: uniqueString(logAnalytics.id)
    environmentVariables: [
      {
        name: 'WORKSPACE_ID'
        value: logAnalytics.name
      }
      {
        name: 'RESOURCE_GROUP'
        value: resourceGroup().name
      }
      {
        name: 'KEYVAULT_NAME'
        value: keyVaultName
      }
      {
        name: 'SECRET_NAME'
        value: logAnalyticsKeySecretName
      }
      {
        name: 'SUBSCRIPTION_ID'
        value: subscription().subscriptionId
      }
    ]
    scriptContent: '''
      set -e
      az login --identity --allow-no-subscriptions
      az account set --subscription "$SUBSCRIPTION_ID"
      KEY=$(az monitor log-analytics workspace get-shared-keys --resource-group "$RESOURCE_GROUP" --workspace-name "$WORKSPACE_ID" --query primarySharedKey -o tsv)
      az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "$SECRET_NAME" --value "$KEY"
    '''
    retentionInterval: 'P1D'
  }
  dependsOn: [keyVault]
}


output logAnalyticsWorkspaceId string = logAnalytics.id
output logAnalyticsWorkspaceCustomerId string = logAnalytics.properties.customerId
output logAnalyticsWorkspaceKeyVaultSecretUri string = '${keyVault.properties.vaultUri}secrets/${logAnalyticsKeySecretName}'

// Add additional monitoring resources (alerts, solutions, etc.) as needed.
