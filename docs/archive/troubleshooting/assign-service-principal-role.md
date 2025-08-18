# Assign Contributor Role to Service Principal

## Service Principal Details

- **Name**: github-actions-stamps
- **Application (client) ID**: e691193e-4e25-4a72-9185-1ce411aa2fd8
- **Object ID**: d292a2f4-6d7e-41a7-8738-e9d752e81b03
- **Tenant ID**: 16b3c013-d300-468d-ac64-7eda0820b6d3

## Target Subscription

- **Subscription**: MCAPS-Hybrid-REQ-103709-2024-scnichol-Hub
- **Subscription ID**: 480cb033-9a92-4912-9d30-c6b7bf795a87

## Steps to Assign Role via Azure Portal

1. **Navigate to your subscription**:
   - Go to [Azure Portal](https://portal.azure.com)
   - Search for "Subscriptions" in the top search bar
   - Click on "MCAPS-Hybrid-REQ-103709-2024-scnichol-Hub"

2. **Open Access Control (IAM)**:
   - In the subscription blade, click on "Access control (IAM)" in the left menu

3. **Add Role Assignment**:
   - Click the "+ Add" button at the top
   - Select "Add role assignment"

4. **Select Role**:
   - In the "Role" tab, search for "Contributor"
   - Select "Contributor" role
   - Click "Next"

5. **Assign Access**:
   - In the "Members" tab:
     - Select "User, group, or service principal"
     - Click "+ Select members"
   - In the search box, enter: `github-actions-stamps`
   - Select the service principal that appears
   - Click "Select"

6. **Review and Assign**:
   - Click "Next" to review
   - Click "Assign" to complete the assignment

## Verification

After completing the role assignment, you can verify it worked by:

- Going back to the subscription's "Access control (IAM)" page
- Click on the "Role assignments" tab
- Look for "github-actions-stamps" in the list with "Contributor" role

## Next Steps

Once the role is assigned:

1. Test GitHub Actions deployment by pushing a commit
2. Check that the deployment succeeds without "No subscriptions found" errors
3. Verify the management portal updates to version 1.2.4 with live data connection

## Alternative: PowerShell Command

If you prefer to use PowerShell (requires Az PowerShell module):

```powershell
# Install Az module if not already installed
Install-Module -Name Az -Force -AllowClobber

# Connect to Azure
Connect-AzAccount -Tenant "16b3c013-d300-468d-ac64-7eda0820b6d3"

# Set subscription context
Set-AzContext -SubscriptionId "480cb033-9a92-4912-9d30-c6b7bf795a87"

# Assign Contributor role
New-AzRoleAssignment -ObjectId "d292a2f4-6d7e-41a7-8738-e9d752e81b03" -RoleDefinitionName "Contributor" -Scope "/subscriptions/480cb033-9a92-4912-9d30-c6b7bf795a87"
```
---

**📝 Document Version Information**
- **Version**: 1.4.0
- **Last Updated**: 2025-08-18 01:28:00 UTC  
- **Status**: Current
- **Next Review**: 2025-11