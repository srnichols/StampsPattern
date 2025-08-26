
@description('Location for regional resources')
param location string

@description('Environment identifier')
param environment string

@description('Unique resource token')
param resourceToken string

@description('Security contact email for alerts')
param securityContactEmail string

@description('Enable advanced threat protection features')
param enableAdvancedThreatProtection bool

@description('Resource group name for resource-scoped resources')
param resourceGroupName string

module advancedSecurityResourceGroup 'advancedSecurityResourceGroup.bicep' = {
  name: 'advancedSecurityResourceGroup'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    environment: environment
    resourceToken: resourceToken
    securityContactEmail: securityContactEmail
    enableAdvancedThreatProtection: enableAdvancedThreatProtection
  }
}

@description('Security Action Group ID')
output securityActionGroupId string = advancedSecurityResourceGroup.outputs.securityActionGroupId

@description('Security Monitoring Workbook ID')
output securityWorkbookId string = advancedSecurityResourceGroup.outputs.securityWorkbookId
