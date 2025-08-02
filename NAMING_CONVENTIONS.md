# 📋 Azure Stamps Pattern - Naming Conventions Guide

## 🎯 Overview

This guide defines the standardized naming conventions for the Azure Stamps Pattern implementation to ensure consistency, clarity, and Azure best practices compliance.

## 🌍 **Resource Group Naming**

### **Pattern**: `rg-{purpose}-{region-short}-{environment}`

| Component | Description | Examples |
|-----------|-------------|----------|
| `rg` | Resource Group prefix | Fixed |
| `{purpose}` | Project/workload identifier | `stamps`, `stamps-global` |
| `{region-short}` | Azure region abbreviation | `eus`, `wus`, `neu`, `weu` |
| `{environment}` | Environment identifier | `dev`, `test`, `prod` |

### **Examples**:
- `rg-stamps-eus-dev` (East US Development)
- `rg-stamps-wus-prod` (West US Production)  
- `rg-stamps-neu-test` (North Europe Test)
- `rg-stamps-global-prod` (Global/multi-region resources)

## 🗺️ **Azure Region Abbreviations**

| Region | Short Name | Region | Short Name |
|--------|------------|--------|------------|
| eastus | eus | westus | wus |
| eastus2 | eus2 | westus2 | wus2 |
| centralus | cus | westus3 | wus3 |
| northcentralus | ncus | southcentralus | scus |
| canadacentral | cac | canadaeast | cae |
| brazilsouth | brs | | |
| **Europe** | | **Asia Pacific** | |
| northeurope | neu | southeastasia | sea |
| westeurope | weu | eastasia | ea |
| francecentral | frc | japaneast | jpe |
| germanywestcentral | gwc | japanwest | jpw |
| norwayeast | noe | koreacentral | krc |
| uksouth | uks | australiaeast | aue |
| ukwest | ukw | centralindia | cin |

## 🏗️ **Resource Naming Patterns**

### **Compute Resources**
```bicep
// Application Gateway
'agw-{geo}-{region-short}-{environment}'
// Example: agw-us-eus-prod

// Container Apps  
'ca-{cell-name}-{region-short}-{environment}'
// Example: ca-banking-eus-prod

// Function Apps
'func-{purpose}-{region-short}-{environment}'
// Example: func-tenant-mgmt-eus-prod
```

### **Data Resources**
```bicep
// SQL Server
'sql-{geo}-{region-short}-{cell}-{environment}'
// Example: sql-us-eus-banking-prod

// SQL Database
'sqldb-{geo}-{region-short}-{cell}-{environment}'
// Example: sqldb-us-eus-banking-prod

// Cosmos DB (Global)
'cosmos-{purpose}-global'
// Example: cosmos-stamps-global

// Cosmos DB (Cell)
'cosmos-{geo}-{region-short}-{cell}-{environment}'
// Example: cosmos-us-eus-banking-prod

// Storage Account (24 char limit)
'st{geo}{regionshort}{cell}{env}'
// Example: stuseusbankingprd (23 chars)
```

### **Networking Resources**
```bicep
// Virtual Network
'vnet-{purpose}-{region-short}-{environment}'
// Example: vnet-stamps-eus-prod

// Subnet
'snet-{purpose}-{region-short}-{environment}'
// Example: snet-stamps-eus-prod

// Public IP
'pip-{resource}-{region-short}-{environment}'
// Example: pip-agw-eus-prod

// Traffic Manager
'tm-{purpose}-global'
// Example: tm-stamps-global

// Front Door
'fd-{purpose}-global'
// Example: fd-stamps-global
```

### **Security & Management**
```bicep
// Key Vault
'kv-{geo}-{region-short}-{environment}'
// Example: kv-us-eus-prod

// Log Analytics Workspace
'law-{purpose}-{region-short}-{environment}'
// Example: law-stamps-eus-prod

// Application Insights
'ai-{purpose}-{region-short}-{environment}'
// Example: ai-stamps-eus-prod

// Automation Account
'auto-{geo}-{region-short}-{environment}'
// Example: auto-us-eus-prod
```

### **Container Resources**
```bicep
// Container Registry
'acr{geo}{regionshort}{environment}'
// Example: acruseusprod

// Container App Environment
'cae-{purpose}-{region-short}-{environment}'
// Example: cae-stamps-eus-prod
```

## 🏷️ **Tagging Strategy**

### **Mandatory Tags**
```json
{
  "environment": "dev|test|prod",
  "geo": "us|eu|asia",
  "region": "eastus|westus|northeurope",
  "cell": "banking|retail|healthcare",
  "workload": "stamps-pattern",
  "costCenter": "IT-Infrastructure",
  "owner": "platform-team@contoso.com"
}
```

### **Optional Tags**
```json
{
  "backup": "daily|weekly|none",
  "monitoring": "enabled|disabled", 
  "compliance": "pci|hipaa|sox",
  "dataClassification": "public|internal|confidential"
}
```

## 📝 **Implementation Guidelines**

### **Bicep Template Variables**
```bicep
// Region mapping helper
var regionShortNames = {
  eastus: 'eus'
  eastus2: 'eus2'
  westus: 'wus'
  westus2: 'wus2'
  westus3: 'wus3'
  northeurope: 'neu'
  westeurope: 'weu'
}

// Generate standardized names
var regionShort = contains(regionShortNames, location) ? regionShortNames[location] : take(location, 3)
var resourceGroupName = 'rg-stamps-${regionShort}-${environment}'
var sqlServerName = 'sql-${geoName}-${regionShort}-${cellName}-${environment}'
```

### **PowerShell Helper Function**
```powershell
function Get-RegionShortName {
    param([string]$Location)
    
    $RegionMap = @{
        'eastus' = 'eus'; 'westus' = 'wus'; 'northeurope' = 'neu'
        'westeurope' = 'weu'; 'eastus2' = 'eus2'; 'westus2' = 'wus2'
    }
    
    return $RegionMap[$Location] ?? $Location.Substring(0, [Math]::Min(3, $Location.Length))
}

$RegionShort = Get-RegionShortName -Location $Location
$ResourceGroupName = "rg-stamps-$RegionShort-$Environment"
```

### **Bash Helper Function**
```bash
get_region_short() {
    case $1 in
        eastus) echo "eus" ;;
        westus) echo "wus" ;;
        northeurope) echo "neu" ;;
        westeurope) echo "weu" ;;
        eastus2) echo "eus2" ;;
        westus2) echo "wus2" ;;
        *) echo "${1:0:3}" ;;
    esac
}

REGION_SHORT=$(get_region_short "$LOCATION")
RESOURCE_GROUP_NAME="rg-stamps-${REGION_SHORT}-${ENVIRONMENT}"
```

## ✅ **Validation Rules**

### **Resource Group Names**
- ✅ Must include region abbreviation
- ✅ Must include environment suffix
- ✅ Maximum 90 characters
- ✅ Pattern: `rg-{purpose}-{region-short}-{environment}`

### **Storage Account Names**
- ✅ Must be globally unique
- ✅ Maximum 24 characters
- ✅ Lowercase letters and numbers only
- ✅ Pattern: `st{geo}{regionshort}{cell}{env}`

### **Resource Names**
- ✅ Must indicate purpose/function
- ✅ Must include region and environment
- ✅ Must follow Azure naming conventions
- ✅ Must be consistent across templates

## 🔧 **Migration Guidelines**

### **Existing Resources**
1. **Assessment**: Identify non-compliant resource names
2. **Planning**: Create migration plan with downtime windows
3. **Execution**: Use Azure Resource Manager move operations where possible
4. **Validation**: Verify all references are updated

### **New Deployments**
1. **Templates**: Update all Bicep templates with new naming patterns
2. **Parameters**: Update parameter files with correct names
3. **Documentation**: Update all guides and examples
4. **CI/CD**: Update pipeline variables and scripts

---

## 📚 **References**

- [Azure Naming Conventions](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)
- [Azure Resource Abbreviations](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)
- [Azure Tagging Strategy](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging)
