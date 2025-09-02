# Management Portal Production Deployment Guide

This guide covers deploying the Azure Stamps Pattern Management Portal to production using Azure Container Apps.

## Overview

The management portal consists of a single main component:

- **Portal Application**: Blazor Server app with advanced SaaS features and integrated Hot Chocolate GraphQL API for all data access

## Prerequisites

1. **Azure CLI**: Install and login to your Azure subscription
2. **Docker**: Required for building container images
3. **PowerShell**: For running deployment scripts (Windows/Linux/macOS)
4. **Azure Entra ID App Registration**: For authentication (see setup below)

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Azure Front  │    │  Container Apps  │    │   Cosmos DB     │
│      Door      │───▶│   Environment    │───▶│   (Control      │
│                │    │                  │    │    Plane)       │
└─────────────────┘    │  ┌─────────────┐ │    └─────────────────┘
                      │  │   Portal    │ │    ┌─────────────────┐
                      │  │   App       │ │───▶│  Application    │
                      │  │ (Blazor +   │ │    │   Insights      │
                      │  │  HotChoco)  │ │    └─────────────────┘
                      │  └─────────────┘ │    ┌─────────────────┐
                      └──────────────────┘    │ Container       │
                                              │ Registry        │
                                              └─────────────────┘
```

## Step 1: Azure Entra ID Setup

1. **Create App Registration**:

   ```bash
   az ad app create --display-name "Stamps Management Portal" \
     --web-redirect-uris "https://[YOUR-PORTAL-DOMAIN]/signin-oidc" \
     --web-home-page-url "https://[YOUR-PORTAL-DOMAIN]"
   ```

2. **Configure Authentication**:
   - Enable ID tokens
   - Set logout URL: `https://[YOUR-PORTAL-DOMAIN]/signout-callback-oidc`
   - Add required API permissions for Microsoft Graph (optional)

3. **Create Client Secret**:

   ```bash
   az ad app credential reset --id [APP-ID]
   ```

4. **Update Configuration**:
   Edit `src/Portal/appsettings.Production.json`:

   ```json
   {
     "AzureAd": {
       "TenantId": "[YOUR-TENANT-ID]",
       "ClientId": "[YOUR-CLIENT-ID]",
       "ClientSecret": "[YOUR-CLIENT-SECRET]"
     }
   }
   ```

## Step 2: Deploy Infrastructure

Run the deployment script:

```powershell
./deploy-management-portal-container-apps.ps1 -ResourceGroupName "rg-stamps-mgmt-prod" -SubscriptionId "YOUR-SUBSCRIPTION-ID" -Location "westus2"
```

This script will:

1. Create/update resource group
2. Deploy Azure infrastructure (Cosmos DB, Container Apps, etc.)
3. Build and push container images
4. Deploy the portal application to Container Apps

## Step 3: Configure Authentication

After deployment, update the Container Apps with authentication settings:

```bash
# Set Azure AD configuration
az containerapp update \
  --name ca-stamps-portal \
  --resource-group rg-stamps-mgmt-prod \
  --set-env-vars \
    "AzureAd__TenantId=[YOUR-TENANT-ID]" \
    "AzureAd__ClientId=[YOUR-CLIENT-ID]" \
  --secrets \
    "azure-ad-client-secret=[YOUR-CLIENT-SECRET]"
```

### Secret lifetime and rotation

- The client secret often expires in ~30 days due to tenant policy. To rotate it quickly, re-run the helper script:

   ```powershell
   pwsh -File ./scripts/configure-entra-auth.ps1 \ 
      -ResourceGroup <your-rg> \ 
      -ContainerAppName ca-stamps-portal \ 
      -TenantId <your-tenant-id>
   ```

   This creates a new app registration or reuses the latest one, sets the redirect URI to your Container App default URL, generates a policy-compliant secret, and updates the Container App secrets/env vars.

- For longer-lived credentials, work with your AAD admin to adjust secret lifetime policy, or avoid secrets by using federated credentials (workload identity) with Azure Container Apps.
- After updating secrets, the Container App may need a revision restart for changes to take effect.

## Step 4: Verify Deployment

1. **Check Application Health**:

   ```bash
   curl https://[PORTAL-URL]/health
   ```

2. **Test Authentication**:
   Navigate to the portal URL and verify login flow

3. **Verify GraphQL API**:

   ```bash
   curl https://[PORTAL-URL]/graphql \
     -H "Content-Type: application/json" \
     -d '{"query": "{ __schema { types { name } } }"}'
   ```

## Infrastructure Components

| Component | Purpose | SKU/Configuration |
|-----------|---------|-------------------|
| **Container Apps Environment** | Hosting platform | Log Analytics integration |
| **Container Apps** | Portal hosting (Blazor + Hot Chocolate GraphQL) | Auto-scaling (1-5 replicas) |
| **Cosmos DB** | Control plane database | Serverless, multi-region |
| **Container Registry** | Image storage | Basic SKU |
| **Application Insights** | Monitoring & telemetry | Standard |
| **Log Analytics** | Centralized logging | PerGB2018 pricing tier |
| **Managed Identity** | Secure access | System-assigned |

## Security Features

- **Azure Entra ID Integration**: Enterprise authentication
- **Role-Based Access Control**: Platform admin and authenticated user roles
- **Container Security**: Non-root user execution
- **Network Security**: Internal communication
- **Managed Identity**: Secure Azure resource access

## Monitoring & Operations

### Key Metrics to Monitor

1. **Application Performance**:
   - Response times
   - Request rates
   - Error rates

2. **Container Health**:
   - CPU/Memory utilization
   - Container restart counts
   - Auto-scaling events

3. **Database Performance**:
   - Cosmos DB RU consumption
   - Query performance
   - Connection counts

### Logging

Logs are centralized in Log Analytics workspace:

```kql
// Application logs
ContainerAppConsoleLogs_CL
| where ContainerName_s == "portal"
| order by TimeGenerated desc

// Performance metrics
ContainerAppSystemLogs_CL
| where Type_s == "Warning" or Type_s == "Error"
| order by TimeGenerated desc
```

## Scaling Configuration

### Portal Application

- **Min Replicas**: 1
- **Max Replicas**: 5
- **Scale Rule**: HTTP requests (50 concurrent)
- **Resources**: 0.5 CPU, 1GB RAM

## Troubleshooting

### Common Issues

1. **Authentication Failures**:
   - Verify Azure AD app registration
   - Check redirect URLs
   - Validate client secret
   - Error AADSTS700016 (app not found): ensure the app was created in the correct tenant and the redirect URI matches your Container App URL (default: `https://<fqdn>/signin-oidc`). Running `scripts/configure-entra-auth.ps1` can fix this end-to-end.

2. **Database Connection Issues**:
   - Check Cosmos DB connection string
   - Verify managed identity permissions
   - Review network connectivity

3. **Container Startup Failures**:
   - Check application logs
   - Verify environment variables
   - Review Docker image build

### Debug Commands

```bash
# Check container app status
az containerapp show --name ca-stamps-portal --resource-group rg-stamps-mgmt-prod

# View application logs
az containerapp logs show --name ca-stamps-portal --resource-group rg-stamps-mgmt-prod

# Check replica status
az containerapp replica list --name ca-stamps-portal --resource-group rg-stamps-mgmt-prod
```

## Cost Optimization

- **Cosmos DB**: Serverless billing (pay per use)
- **Container Apps**: Scale to zero when idle
- **Application Insights**: Sampling to reduce costs
- **Log Analytics**: 30-day retention for cost control

## Next Steps

1. **Custom Domain**: Configure custom domain and SSL certificates
2. **Monitoring Alerts**: Set up proactive monitoring alerts
3. **CI/CD Pipeline**: Automate deployments with GitHub Actions
4. **Backup Strategy**: Implement database backup procedures
5. **Disaster Recovery**: Configure multi-region deployment

## Support

For issues or questions:

1. Check Application Insights for errors
2. Review Container Apps logs
3. Consult Azure documentation
4. Contact your Azure support team
