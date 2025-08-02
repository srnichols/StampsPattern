# 🔧 Azure Stamps Pattern - Naming Convention Updates

## 📋 **Changes Made**

This document summarizes the naming convention improvements applied to the Azure Stamps Pattern repository.

---

## 🎯 **Issues Identified & Fixed**

### ❌ **Issue 1: Resource Group Names Missing Region Codes**
**Problem**: Resource groups used generic names without Azure region abbreviations
- `rg-stamps-dev` → **Missing region context**
- `rg-stamps-global` → **Acceptable for global resources**
- `rg-stamps-production` → **Missing region context**

**✅ Solution Applied**:
- Created standardized region mapping in `azure-region-mapping.json`
- Updated deployment scripts to generate region-aware names:
  - `rg-stamps-eus-dev` (East US Development)
  - `rg-stamps-wus-prod` (West US Production)
  - `rg-stamps-neu-test` (North Europe Test)

### ❌ **Issue 2: Inconsistent Resource Naming Patterns**
**Problem**: Mixed naming conventions across templates
- Some used full region names (`eastus`, `westeurope`)
- Others used no region identifiers
- Storage accounts risked exceeding 24-character limit

**✅ Solution Applied**:
- Created comprehensive naming standards in `NAMING_CONVENTIONS.md`
- Updated `traffic-routing.bicep` with region mapping logic
- Standardized resource names:
  ```bicep
  // Before
  'stamps-apim-dev' 
  
  // After  
  'stamps-apim-eus-dev'
  ```

### ❌ **Issue 3: Storage Account Naming Issues**
**Problem**: Storage account names could exceed Azure's 24-character limit
- Pattern: `st${geo.geoName}${region.regionName}${cell}` → Too long
- Example: `stUnitedStateseastusbanking` → 26 characters ❌

**✅ Solution Applied**:
- Updated to use region abbreviations:
  ```bicep
  // Before: stUnitedStateseastusbanking (26 chars)
  // After:  stuseusbankingprd (17 chars) ✅
  ```

### ❌ **Issue 4: Hard-coded Resource References**
**Problem**: Templates contained hard-coded subscription IDs and resource names
- Made templates non-portable
- Required manual updates for different environments

**✅ Solution Applied**:
- Maintained parameterized approach in templates
- Enhanced parameter validation
- Improved template portability

---

## 📁 **Files Modified**

### **Infrastructure Templates**
- ✅ `traffic-routing.bicep` - Added region mapping and improved naming
- ✅ `azure-region-mapping.json` - Created central region mapping

### **Deployment Scripts**
- ✅ `deploy-stamps.sh` - Updated with region-aware resource group naming
- ✅ `deploy-stamps.ps1` - Updated with region-aware resource group naming

### **Documentation**
- ✅ `NAMING_CONVENTIONS.md` - **NEW** Comprehensive naming standards guide
- ✅ `DEPLOYMENT_GUIDE.md` - Updated examples with correct resource group names
- ✅ `README.md` - Updated examples with proper naming patterns
- ✅ `DOCS.md` - Added naming conventions to documentation hub

---

## 🗺️ **Region Mapping Reference**

| Azure Region | Short Code | Example Usage |
|--------------|------------|---------------|
| eastus | eus | `rg-stamps-eus-prod` |
| westus | wus | `rg-stamps-wus-prod` |
| eastus2 | eus2 | `rg-stamps-eus2-prod` |
| westus2 | wus2 | `rg-stamps-wus2-prod` |
| northeurope | neu | `rg-stamps-neu-prod` |
| westeurope | weu | `rg-stamps-weu-prod` |
| southeastasia | sea | `rg-stamps-sea-prod` |
| eastasia | ea | `rg-stamps-ea-prod` |

---

## 🏗️ **Updated Resource Naming Examples**

### **Before (Inconsistent)**
```bash
# Resource Groups
rg-stamps-dev
rg-stamps-production

# Resources  
stamps-apim-dev
stamps-cosmos-dev
stamps-agw-dev
```

### **After (Standardized)**
```bash
# Resource Groups with Region Context
rg-stamps-eus-dev
rg-stamps-eus-production
rg-stamps-weu-production

# Resources with Region Context
stamps-apim-eus-dev
stamps-cosmos-eus-dev  
stamps-agw-eus-dev
```

---

## 🚀 **Implementation Guidelines**

### **For New Deployments**
1. Use updated deployment scripts (`deploy-stamps.sh` or `deploy-stamps.ps1`)
2. Reference `NAMING_CONVENTIONS.md` for all resource naming
3. Validate storage account names don't exceed 24 characters
4. Include region abbreviations in all regional resources

### **For Existing Deployments**
1. **Assessment Phase**: 
   - Inventory current resource names
   - Identify non-compliant naming patterns
   
2. **Migration Phase**:
   - Plan maintenance windows for resource moves
   - Update parameter files with new naming patterns
   - Test deployments in development first
   
3. **Validation Phase**:
   - Verify all references are updated
   - Test application connectivity
   - Update monitoring and alerting

---

## ✅ **Validation Checklist**

- ✅ Resource groups include region abbreviations
- ✅ Storage account names ≤ 24 characters
- ✅ All regional resources include region context
- ✅ Global resources clearly identified
- ✅ Deployment scripts updated
- ✅ Documentation reflects new standards
- ✅ Examples use correct naming patterns

---

## 🔗 **Related Documentation**

- [Complete Naming Conventions Guide](./NAMING_CONVENTIONS.md)
- [Updated Deployment Guide](./DEPLOYMENT_GUIDE.md)
- [Architecture Guide](./ARCHITECTURE_GUIDE.md)
- [Documentation Hub](./DOCS.md)

---

## 📝 **Notes**

- All changes maintain backward compatibility where possible
- New deployments should use updated naming standards
- Existing deployments can migrate during next maintenance window
- Global resources (Traffic Manager, Front Door) don't require region codes
- CELLs remain flexible for tenant-specific naming requirements
