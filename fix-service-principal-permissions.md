# Fix Service Principal Permissions

The authentication is working, but the service principal can't access the subscription. Here's how to fix it:

## Step 1: Verify Role Assignment in Azure Portal

1. **Go to**: https://portal.azure.com
2. **Navigate to**: Subscriptions → **MCAPS-Hybrid-REQ-103709-2024-scnichol-Hub**
3. **Click on**: Access control (IAM)
4. **Click**: "Role assignments" tab
5. **Search for**: `github-actions-stamps-sp`

## Step 2: If Service Principal is Missing, Add It

If you don't see your service principal, add it:

1. **Click**: "Add" → "Add role assignment"
2. **Role**: Select "Contributor" 
3. **Click**: "Next"
4. **Assign access to**: "User, group, or service principal"
5. **Click**: "Select members"
6. **Search for**: `github-actions-stamps-sp`
7. **Select it** and click "Select"
8. **Click**: "Review + assign"

## Step 3: Alternative - Use Application ID

If searching by name doesn't work, try searching by the Application ID:
- Search for: `e691193e-4e25-4a72-9185-1ce411aa2fd8`

## Step 4: Verify Tenant Context

Make sure you're in the correct tenant:
- **Current tenant should be**: `16b3c013-d300-468d-ac64-7eda0820b6d3`
- **Check the top-right corner** of Azure Portal for tenant name

## Step 5: Alternative Fix - Re-create Service Principal

If the above doesn't work, the service principal might not have been created properly:

1. **Microsoft Entra ID** → **App registrations** 
2. **Find**: `github-actions-stamps-sp`
3. **Delete it** if it exists
4. **Create a new one** with the same name
5. **Copy the new client ID, tenant ID, and secret**
6. **Update GitHub secrets** with new values
7. **Assign Contributor role** to the new service principal

The key issue is that the service principal exists but doesn't have access to the subscription where your container apps live.
