// Configure Microsoft Defender for Cloud pricing plans at subscription scope
// Goal: reduce costs by setting expensive plans to Free while keeping CSPM/policy posture
// Notes:
// - 'Microsoft.Security/pricings' supports pricingTier: 'Free' or 'Standard'
// - For VirtualMachines, subPlan supports 'P1' or 'P2' when pricingTier is 'Standard'
// - Leave CSPM (Arm) at 'Free' to keep secure score and policy evaluations without cost

targetScope = 'subscription'

@description('Deployment environment (dev, test, staging, prod) for defaults')
@allowed(['dev','test','staging','prod'])
param environment string = 'test'

@description('Defender for Servers plan: Off (Free), P1, or P2. P1/P2 incur costs.')
@allowed(['Off','P1','P2'])
param defenderForServersPlan string = (environment == 'prod' ? 'P1' : 'Off')

@description('Enable Defender for Storage (Standard) — costs per 10K transactions. Default off outside prod.')
param enableDefenderForStorage bool = (environment == 'prod' ? true : false)

@description('Enable Defender for SQL (Standard). Default off outside prod.')
param enableDefenderForSql bool = (environment == 'prod' ? true : false)

@description('Enable Defender for App Services (Standard). Default off outside prod.')
param enableDefenderForAppServices bool = false

@description('Enable Defender for Key Vault (Standard). Default off outside prod.')
param enableDefenderForKeyVault bool = false

// Keep CSPM/Secure Score at Free tier to preserve policy/assessment features (CloudPosture)
resource pricingCloudPosture 'Microsoft.Security/pricings@2024-01-01' = {
  name: 'CloudPosture'
  properties: {
    pricingTier: 'Free'
  }
}

// Defender for Servers (VirtualMachines)
resource pricingVms 'Microsoft.Security/pricings@2024-01-01' = {
  name: 'VirtualMachines'
  properties: {
    pricingTier: defenderForServersPlan == 'Off' ? 'Free' : 'Standard'
    subPlan: defenderForServersPlan == 'Off' ? null : defenderForServersPlan
  }
}

// Storage Accounts
resource pricingStorage 'Microsoft.Security/pricings@2024-01-01' = {
  name: 'StorageAccounts'
  properties: {
    pricingTier: enableDefenderForStorage ? 'Standard' : 'Free'
  }
}

// SQL Servers (PaaS)
resource pricingSql 'Microsoft.Security/pricings@2024-01-01' = {
  name: 'SqlServers'
  properties: {
    pricingTier: enableDefenderForSql ? 'Standard' : 'Free'
  }
}

// App Services
resource pricingAppServices 'Microsoft.Security/pricings@2024-01-01' = {
  name: 'AppServices'
  properties: {
    pricingTier: enableDefenderForAppServices ? 'Standard' : 'Free'
  }
}

// Key Vaults
resource pricingKeyVaults 'Microsoft.Security/pricings@2024-01-01' = {
  name: 'KeyVaults'
  properties: {
    pricingTier: enableDefenderForKeyVault ? 'Standard' : 'Free'
  }
}

// Kubernetes (AKS) — keep at Free unless required
resource pricingK8s 'Microsoft.Security/pricings@2024-01-01' = {
  name: 'KubernetesService'
  properties: {
    pricingTier: 'Free'
  }
}

// Containers (registries) — keep at Free
resource pricingContainers 'Microsoft.Security/pricings@2024-01-01' = {
  name: 'Containers'
  properties: {
    pricingTier: 'Free'
  }
}

// Open Source Relational DBs (Flexible Server) — keep at Free
resource pricingOssDb 'Microsoft.Security/pricings@2024-01-01' = {
  name: 'OpenSourceRelationalDatabases'
  properties: {
    pricingTier: 'Free'
  }
}
