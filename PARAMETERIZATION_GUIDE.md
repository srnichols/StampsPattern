# 📋 Template Parameterization Guide

**Enterprise Multi-Organization Deployment Support**

## 🎯 Overview

The Azure Stamps Pattern templates have been enhanced with comprehensive parameterization to make them reusable across different organizations, geographies, and environments. All previously hardcoded values are now configurable parameters, enabling **enterprise-grade multi-organization support** with custom domains, branding, and geographic deployment strategies.

## 🔧 New Parameters Added

### **Organization Parameters**
| Parameter | Description | Default Value | Usage |
|-----------|-------------|---------------|-------|
| `organizationDomain` | The organization domain (e.g., contoso.com) | `contoso.com` | DNS zones, email addresses |
| `organizationName` | The organization name for resource naming | `contoso` | Resource naming (future use) |
| `department` | The department responsible for the deployment | `IT` | Resource tagging |
| `projectName` | The project name for resource tagging and naming | `StampsPattern` | Resource tagging |
| `workloadName` | The workload name for resource tagging | `stamps-pattern` | Resource tagging |
| `ownerEmail` | The owner email for resource tagging | `platform-team@contoso.com` | Resource tagging |

### **Geography Parameters**
| Parameter | Description | Default Value | Usage |
|-----------|-------------|---------------|-------|
| `geoName` | The geography name (e.g., northamerica, europe, asia) | `northamerica` | Resource naming, tagging |
| `baseDnsZoneName` | The base DNS zone name (without domain) | `stamps` | DNS zone construction |

### **Computed Parameters**
| Parameter | Description | Computed From |
|-----------|-------------|---------------|
| `dnsZoneName` | The complete DNS zone name | `${baseDnsZoneName}.${organizationDomain}` |

## 🏗️ Template Changes Made

### **1. Parameter Additions**
```bicep
// Organization Parameters
@description('The organization domain (e.g., contoso.com)')
param organizationDomain string = 'contoso.com'

@description('The geography name (e.g., northamerica, europe, asia)')
param geoName string = 'northamerica'

@description('The base DNS zone name (without domain)')
param baseDnsZoneName string = 'stamps'
```

### **2. Dynamic DNS Zone Construction**
```bicep
// Before (hardcoded):
param dnsZoneName string = 'stamps.contoso.com'

// After (computed):
param dnsZoneName string = '${baseDnsZoneName}.${organizationDomain}'
```

### **3. Dynamic Base Domains**
```bicep
// Before (hardcoded):
baseDomain: 'eastus.stamps.contoso.com'

// After (computed):
baseDomain: 'eastus.${baseDnsZoneName}.${organizationDomain}'
```

### **4. Parameterized Tags**
```bicep
// Before (hardcoded):
var baseTags = {
  department: 'IT'
  project: 'StampsPattern'
  owner: 'platform-team@contoso.com'
}

// After (parameterized):
var baseTags = {
  department: department
  project: projectName
  owner: ownerEmail
}
```

### **5. Parameterized Geography**
```bicep
// Before (hardcoded):
geoName: 'northamerica'

// After (parameterized):
geoName: geoName
```

## 🚀 PowerShell Script Updates

### **New Parameters Added**
```powershell
[Parameter(Mandatory = $false)]
[string]$OrganizationDomain = "contoso.com",

[Parameter(Mandatory = $false)]
[string]$GeoName = "northamerica",

[Parameter(Mandatory = $false)]
[string]$BaseDnsZoneName = "stamps"
```

### **Updated Domain Construction**
```powershell
# Before (hardcoded):
baseDomain = "$Location.stamps.contoso.com"

# After (parameterized):
baseDomain = "$Location.$BaseDnsZoneName.$OrganizationDomain"
```

## 📝 Usage Examples

### **Example 1: Different Organization**
```powershell
.\deploy-stamps.ps1 `
  -ResourceGroupName "rg-stamps-prod" `
  -Location "eastus" `
  -OrganizationDomain "fabrikam.com" `
  -OrganizationName "fabrikam" `
  -Department "Engineering" `
  -OwnerEmail "devops-team@fabrikam.com"
```

### **Example 2: European Geography**
```powershell
.\deploy-stamps.ps1 `
  -ResourceGroupName "rg-stamps-eu-prod" `
  -Location "westeurope" `
  -GeoName "europe" `
  -OrganizationDomain "company.eu" `
  -BaseDnsZoneName "microservices"
```

### **Example 3: Using Parameters File**
```json
{
  "organizationDomain": { "value": "healthcare.org" },
  "organizationName": { "value": "healthcorp" },
  "department": { "value": "IT-Healthcare" },
  "projectName": { "value": "PatientPortal" },
  "geoName": { "value": "northamerica" },
  "baseDnsZoneName": { "value": "portal" }
}
```

## ✅ Benefits Achieved

### **1. Multi-Organization Support**
- ✅ **Complete Domain Flexibility**: Any organization can use their own domain
- ✅ **Custom Branding**: Organization name, department, project name are configurable
- ✅ **Email Customization**: Owner contact information is parameterized

### **2. Multi-Geography Support**
- ✅ **Geography Flexibility**: Support for different geographic regions (US, Europe, Asia)
- ✅ **Region-Agnostic**: No hardcoded region assumptions
- ✅ **Localized Naming**: Geographic context preserved in resource names

### **3. Environment Flexibility**
- ✅ **DNS Zone Flexibility**: Custom DNS zone patterns for different environments
- ✅ **Subdomain Control**: Complete control over subdomain structure
- ✅ **Multi-Environment**: Support for dev, test, staging, prod with appropriate DNS

### **4. Operational Excellence**
- ✅ **Proper Tagging**: All resources properly tagged with configurable metadata
- ✅ **Ownership Tracking**: Clear ownership information in tags
- ✅ **Cost Allocation**: Department and project tags for cost tracking

## 🔍 Validation

### **Template Validation**
```powershell
# Validate the Bicep template
az deployment group validate `
  --resource-group "rg-stamps-test" `
  --template-file "AzureArchitecture/main.bicep" `
  --parameters "@AzureArchitecture/main.parameters.example.json"
```

### **Parameter File Validation**
- ✅ All required parameters have default values
- ✅ Parameter file example includes all new parameters
- ✅ PowerShell script passes all new parameters correctly

## 🎭 Migration Notes

### **For Existing Deployments**
1. **Review Current Values**: Document current hardcoded values
2. **Update Parameters**: Use current values as parameter defaults
3. **Test in Dev**: Validate new parameters in development environment
4. **Gradual Rollout**: Update environments incrementally

### **For New Deployments**
1. **Copy Example File**: Use `main.parameters.example.json` as starting point
2. **Customize Values**: Update all organization-specific parameters
3. **Validate Template**: Run validation before deployment
4. **Deploy**: Use enhanced PowerShell script with new parameters

---

## 📚 Related Documentation

- [NAMING_CONVENTIONS.md](../NAMING_CONVENTIONS.md) - Zone-aware naming patterns
- [DEPLOYMENT_GUIDE.md](../DEPLOYMENT_GUIDE.md) - Deployment procedures
- [Azure Naming Conventions](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)
