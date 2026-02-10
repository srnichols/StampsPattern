# Observability — Instructions

applyTo: "AzureArchitecture/monitoringLayer.bicep,AzureArchitecture/monitoringDashboards.bicep,AzureArchitecture/enhancedMonitoring.bicep,AzureArchitecture/**/*.cs"

## Observability Architecture

The solution implements a comprehensive observability stack covering logging, metrics, alerting, and dashboards.

### Monitoring Infrastructure (Bicep)

| Module | Purpose |
|--------|---------|
| `monitoringLayer.bicep` | Log Analytics workspace, Application Insights |
| `monitoringDashboards.bicep` | Metric alerts, workbooks, AI-driven insights |
| `enhancedMonitoring.bicep` | Cache performance alerts, security alerts |

All resources send diagnostics to the **central Log Analytics workspace**, passed as `globalLogAnalyticsWorkspaceId` through the module chain.

### Logging

#### Structured Logging (C#)

Use `ILogger<T>` with structured message templates — **never** string interpolation:

```csharp
// CORRECT
_logger.LogInformation("Creating tenant {TenantId} in region {Region}", tenant.tenantId, tenant.region);
_logger.LogError(ex, "Cosmos DB error for tenant {TenantId}", tenantId);

// WRONG
_logger.LogInformation($"Creating tenant {tenant.tenantId}"); // loses structured data
Console.WriteLine($"Creating tenant {tenant.tenantId}");       // no structure, no level
```

#### Log Levels

| Level | Use For |
|-------|---------|
| `Debug` | Cache hits/misses, internal state details |
| `Information` | Operation start/complete, CELL assignments, tenant creation |
| `Warning` | Validation failures, missing auth headers, cache misses for critical paths |
| `Error` | Exceptions, database failures, external service failures |

#### host.json Logging Configuration

```json
{
  "logging": {
    "logLevel": {
      "default": "Information",
      "Host.Results": "Error",
      "Function": "Information",
      "Host.Aggregator": "Trace"
    },
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "excludedTypes": "Request"
      }
    }
  }
}
```

### Metrics & Performance Tracking

#### `PerformanceMonitoringService`

In-code metrics collection service tracking:

- `TotalExecutions`, `SuccessfulExecutions`, `FailedExecutions`
- `AverageDurationMs`, `MinDurationMs`, `MaxDurationMs`
- `SuccessRate` — ratio of successful to total executions
- `ErrorCounts` — frequency by exception type

Usage:

```csharp
var result = await _performanceService.MeasureAsync("OperationName", async () => {
    return await DoWorkAsync();
});
```

### Alerting (Bicep)

#### Metric Alerts

| Alert | Threshold | Severity | Window |
|-------|-----------|----------|--------|
| High error rate | >5% failed requests | 2 (Warning) | 5 minutes |
| High response time | >2s P95 latency | 3 (Informational) | 5 minutes |
| Redis cache hit ratio low | <80% | 2 (Warning) | 15 minutes |
| Cache memory high | >90% | 2 (Warning) | 15 minutes |

#### Action Groups

- `performanceActionGroup` — email + Teams webhook for performance alerts
- `cacheActionGroup` — email for cache-specific alerts
- Alert recipients configurable: `alertEmailRecipients` parameter (default: `devops@sdp-saas.com`)
- Common alert schema enabled for all receivers

### Application Insights

- Integrated via `APPINSIGHTS_INSTRUMENTATIONKEY` env var
- Request sampling enabled (excludes Request types to capture all requests)
- Used for distributed tracing, dependency tracking, and custom metrics

### Health Monitoring

- Function host health monitor: 30s interval, 2-minute window, 80% threshold
- `GET /api/health` endpoint returns component-level health:
  - Cosmos DB, Redis Cache, Key Vault connectivity
  - Response times per component
  - Feature list and version info

### Cost Optimization Monitoring

- `costOptimization.bicep` implements:
  - Azure Automation accounts for cost anomaly detection
  - Logic Apps for predictive scaling recommendations
  - Configurable cost threshold alerts (default: $1,000/month)
  - Environment-based cost tracking variables

### Dashboard Conventions

When creating monitoring dashboards:
- Always include tenant-aware filtering
- Show CELL-level metrics alongside global metrics
- Include cost and capacity utilization views
- Use consistent naming: `{prefix}-{metric}-{environment}`
