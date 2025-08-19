# Infrastructure Discovery Function Guide

## Overview

The Infrastructure Discovery Function is an enhanced Azure Function that provides comprehensive infrastructure discovery capabilities for the Stamps Pattern implementation. It bridges the gap between your physical Azure infrastructure and the management portal, enabling real-time visibility into your deployment stamps.

## Features

### Core Capabilities
- **Dual-Mode Discovery**: Supports both simulated and real Azure Resource Manager discovery
- **Pattern Matching**: Advanced regex-based resource group pattern detection
- **Capacity Estimation**: Intelligent capacity calculation based on deployed services
- **Multi-Region Support**: Discovers resources across all Azure regions
- **Real-Time Data**: Live connection to Azure Resource Manager APIs

### Enhanced Pattern Detection
The function uses sophisticated pattern matching to identify stamp resource groups:
- `rg-stamps-*-cell-*`: Primary stamp pattern
- `rg-*-stamp-*`: Alternative stamp pattern  
- `rg-*-cell-*`: Cell-specific pattern
- `*-stamps-*`: Legacy pattern support

### Capacity Estimation Algorithm
Advanced capacity calculation considers:
- **App Services**: Base capacity + scaling potential
- **Container Apps**: Container count × estimated capacity
- **Functions**: Event-driven capacity estimation
- **Databases**: Connection pool and throughput analysis
- **Storage**: Access pattern and performance tier analysis

## API Endpoints

### Discovery Endpoint
```http
GET|POST /api/infrastructure/discover
```

#### Query Parameters
- `mode` (optional): `simulated` or `azure` (default: `simulated`)
- `includeCapacity` (optional): `true` or `false` (default: `true`)

#### Request Body (POST)
```json
{
  "mode": "azure",
  "includeCapacity": true,
  "subscriptionFilter": "subscription-id-here"
}
```

#### Response Format
```json
{
  "discoveryMode": "azure",
  "discoveredAt": "2025-08-19T00:00:00Z",
  "totalCells": 6,
  "cells": [
    {
      "cellId": "cell-eastus-01",
      "cellName": "East US Cell 01", 
      "region": "eastus",
      "resourceGroupName": "rg-stamps-eastus-cell-01",
      "subscriptionId": "12345678-1234-1234-1234-123456789012",
      "status": "Active",
      "services": [
        {
          "name": "app-stamps-web",
          "type": "Microsoft.Web/sites",
          "resourceId": "/subscriptions/.../resourceGroups/.../providers/Microsoft.Web/sites/app-stamps-web",
          "status": "Running",
          "location": "eastus"
        }
      ],
      "estimatedCapacity": {
        "maxTenants": 850,
        "currentUtilization": 0.65,
        "capacityScore": "High",
        "bottleneckServices": ["CosmosDB"],
        "recommendedActions": ["Scale CosmosDB throughput"]
      }
    }
  ],
  "summary": {
    "totalCapacity": 5100,
    "averageUtilization": 0.58,
    "healthyStamps": 6,
    "warningStamps": 0,
    "criticalStamps": 0
  }
}
```

## Usage Examples

### 1. Basic Discovery (Simulated Mode)
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:7071/api/infrastructure/discover" -Method GET
Write-Host "Found $($response.totalCells) cells"
```

### 2. Azure Resource Manager Discovery
```powershell
$body = @{
    mode = "azure"
    includeCapacity = $true
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:7071/api/infrastructure/discover" -Method POST -Body $body -ContentType "application/json"
```

### 3. Portal Integration
```javascript
// Using the infrastructure discovery portal
async function discoverInfrastructure() {
    const response = await fetch('/api/infrastructure/discover?mode=azure');
    const data = await response.json();
    displayCells(data.cells);
}
```

## Configuration

### Environment Variables
- `AZURE_CLIENT_ID`: Azure AD application client ID (for Azure mode)
- `AZURE_CLIENT_SECRET`: Azure AD application client secret
- `AZURE_TENANT_ID`: Azure AD tenant ID
- `COSMOS_CONNECTION_STRING`: Cosmos DB connection for caching

### Local Development
1. Copy `local.settings.template.json` to `local.settings.json`
2. Configure Azure credentials for real discovery
3. Run `func start` to start the local runtime

### Authentication
The function supports multiple authentication methods:
- **DefaultAzureCredential**: Automatic credential resolution
- **Managed Identity**: For Azure-hosted deployments
- **Service Principal**: For CI/CD scenarios
- **Developer Credentials**: For local development

## Integration with Management Portal

### Portal Discovery Page
The infrastructure discovery portal provides:
- Interactive cell visualization
- Real-time capacity monitoring
- Service health indicators
- Capacity trend analysis

### Automated Discovery
Configure automated discovery schedules:
```csharp
// Timer-triggered discovery
[Function("ScheduledDiscovery")]
public async Task RunScheduledDiscovery([TimerTrigger("0 */5 * * * *")] TimerInfo timer)
{
    var discoveryResult = await _infrastructureService.DiscoverInfrastructureAsync("azure");
    await _cacheService.UpdateDiscoveryCache(discoveryResult);
}
```

## Troubleshooting

### Common Issues

#### 1. Authentication Failures
```
Error: DefaultAzureCredential failed to retrieve a token
```
**Solution**: Ensure Azure credentials are properly configured
- Local: Use `az login` or set environment variables
- Azure: Enable Managed Identity on the Function App

#### 2. No Cells Discovered
```
Warning: No stamp resource groups found
```
**Solution**: Verify resource group naming patterns
- Check subscription access permissions
- Validate resource group naming conventions
- Ensure resources exist in expected regions

#### 3. Capacity Estimation Errors
```
Error: Unable to estimate capacity for resource group
```
**Solution**: Check resource access permissions
- Verify Reader role on resource groups
- Ensure Azure Resource Manager connectivity
- Check for API throttling

### Debugging Tips
1. Enable verbose logging in `host.json`
2. Use the portal's error display for detailed diagnostics
3. Check Azure Activity Logs for permission issues
4. Monitor Function execution logs in Application Insights

## Performance Optimization

### Caching Strategy
- **Memory Cache**: 5-minute TTL for discovery results
- **Distributed Cache**: Redis/Cosmos for multi-instance deployments
- **Background Refresh**: Proactive cache warming

### Scaling Considerations
- **Concurrent Discovery**: Parallel resource group processing
- **Regional Filtering**: Limit discovery scope when possible
- **Batch Processing**: Group resource queries for efficiency

## Security Best Practices

### Access Control
- Use least-privilege service principals
- Implement resource-level RBAC
- Audit discovery function access

### Data Protection
- Encrypt discovery results in cache
- Implement secure credential storage
- Use HTTPS for all API calls

### Monitoring
- Track discovery success rates
- Monitor authentication events
- Alert on capacity threshold breaches

## Future Enhancements

### Planned Features
1. **Cost Analysis Integration**: Include cost data in discovery results
2. **Performance Metrics**: Real-time performance monitoring
3. **Predictive Scaling**: ML-based capacity predictions
4. **Multi-Cloud Support**: Extend to AWS and GCP discovery
5. **Compliance Reporting**: Security and compliance posture

### API Versioning
Future API versions will maintain backward compatibility:
- `/api/v2/infrastructure/discover`: Enhanced discovery with cost data
- `/api/v3/infrastructure/discover`: Multi-cloud discovery support

## Support and Contributing

### Getting Help
- Review the [Known Issues](KNOWN_ISSUES.md) documentation
- Check the [Architecture Guide](ARCHITECTURE_GUIDE.md) for context
- Submit issues via GitHub Issues

### Contributing
1. Fork the repository
2. Create a feature branch
3. Implement changes with tests
4. Submit a pull request

## Related Documentation
- [Architecture Guide](ARCHITECTURE_GUIDE.md)
- [Developer Quickstart](DEVELOPER_QUICKSTART.md)
- [Security Guide](SECURITY_GUIDE.md)
- [Operations Guide](OPERATIONS_GUIDE.md)
