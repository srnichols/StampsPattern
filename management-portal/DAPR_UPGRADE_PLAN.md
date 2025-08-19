# Dapr Upgrade Plan for Management Portal

## 🎯 Goals
1. **Immediate**: Solve Azure integration debugging pain points
2. **Strategic**: Enable future service growth and resilience

## 📋 Phase 1: Debugging & Observability (Week 1-2)

### 1.1 Add Dapr to Container Apps Environment
```bicep
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${resourceToken}'
  location: location
  properties: {
    daprAIInstrumentationKey: applicationInsights.properties.InstrumentationKey
    daprAIConnectionString: applicationInsights.properties.ConnectionString
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}
```

### 1.2 Enable Dapr Sidecars for Services
**Portal Service:**
```bicep
resource portalApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'portal-${resourceToken}'
  properties: {
    configuration: {
      dapr: {
        enabled: true
        appId: 'portal'
        appProtocol: 'http'
        appPort: 8080
        enableApiLogging: true
      }
    }
  }
}
```

**DAB Service:**
```bicep
resource dabApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'dab-${resourceToken}'
  properties: {
    configuration: {
      dapr: {
        enabled: true
        appId: 'dab'
        appProtocol: 'http'
        appPort: 5000
        enableApiLogging: true
      }
    }
  }
}
```

## 📊 Phase 2: Service-to-Service Communication (Week 2-3)

### 2.1 Replace Direct HTTP calls with Dapr Service Invocation
**Before (Portal → DAB):**
```csharp
var httpClient = new HttpClient();
var response = await httpClient.GetAsync("http://dab:5000/graphql");
```

**After (Portal → DAB via Dapr):**
```csharp
var daprClient = new DaprClient();
var response = await daprClient.InvokeMethodAsync<GraphQLQuery, GraphQLResponse>(
    "dab", 
    "graphql", 
    query,
    new HttpInvocationOptions {
        Timeout = TimeSpan.FromSeconds(30)
    });
```

### 2.2 Add Resilience Policies
```yaml
# dapr-resiliency.yaml
apiVersion: dapr.io/v1alpha1
kind: Resiliency
metadata:
  name: portal-resiliency
spec:
  policies:
    retries:
      azure-api-retry:
        policy: exponential
        duration: 5s
        maxRetries: 3
    circuitBreakers:
      azure-api-cb:
        maxRequests: 3
        timeout: 10s
        trip: consecutiveFailures >= 5
  targets:
    apps:
      dab:
        retry: azure-api-retry
        circuitBreaker: azure-api-cb
```

## 🔐 Phase 3: State Management & Secrets (Week 3-4)

### 3.1 Discovery Result Caching
```csharp
// Cache Azure discovery results
public class DaprCachedDiscoveryService : ICosmosDiscoveryService
{
    private readonly DaprClient _daprClient;
    private readonly ICosmosDiscoveryService _innerService;
    
    public async Task<List<Tenant>> DiscoverTenantsAsync()
    {
        // Try cache first
        var cached = await _daprClient.GetStateAsync<List<Tenant>>("cache-store", "tenants");
        if (cached != null && IsValid(cached))
            return cached;
            
        // Fallback to live discovery
        var tenants = await _innerService.DiscoverTenantsAsync();
        
        // Cache with TTL
        await _daprClient.SaveStateAsync("cache-store", "tenants", tenants, 
            metadata: new Dictionary<string, string> { ["ttlInSeconds"] = "3600" });
            
        return tenants;
    }
}
```

### 3.2 Secure Secrets Management
```csharp
// Replace environment variables with Dapr secrets
public class DaprSecretsConfiguration : IConfiguration
{
    private readonly DaprClient _daprClient;
    
    public async Task<string> GetCosmosConnectionStringAsync()
    {
        var secrets = await _daprClient.GetSecretAsync("azure-keyvault", "cosmos-connection-string");
        return secrets["cosmos-connection-string"];
    }
}
```

## 📮 Phase 4: Event-Driven Architecture (Week 4-5)

### 4.1 Infrastructure Change Events
```csharp
// Publish when infrastructure changes detected
public class EventDrivenDiscoveryService : ICosmosDiscoveryService
{
    public async Task SynchronizeDataAsync()
    {
        var newTenants = await DiscoverTenantsAsync();
        var changes = DetectChanges(newTenants);
        
        foreach (var change in changes)
        {
            await _daprClient.PublishEventAsync("infrastructure-events", "tenant-changed", change);
        }
    }
}

// Subscribe to events in Portal
[Topic("infrastructure-events", "tenant-changed")]
public async Task HandleTenantChanged(TenantChangeEvent changeEvent)
{
    // Update UI, invalidate cache, etc.
    await NotifyClientsAsync(changeEvent);
}
```

## 🔍 Debugging Benefits Implementation

### Distributed Tracing Setup
```csharp
// Program.cs - Add OpenTelemetry
builder.Services.AddOpenTelemetry()
    .WithTracing(builder => builder
        .AddAspNetCoreInstrumentation()
        .AddDaprInstrumentation()
        .AddAzureMonitorTraceExporter());
```

### Custom Metrics for Azure Integration
```csharp
public class AzureIntegrationMetrics
{
    private readonly Counter<int> _azureApiCalls;
    private readonly Histogram<double> _azureApiDuration;
    
    public AzureIntegrationMetrics(IMeterFactory meterFactory)
    {
        var meter = meterFactory.Create("management-portal.azure");
        _azureApiCalls = meter.CreateCounter<int>("azure_api_calls_total");
        _azureApiDuration = meter.CreateHistogram<double>("azure_api_duration_seconds");
    }
    
    public void RecordApiCall(string operation, bool success, double duration)
    {
        _azureApiCalls.Add(1, new TagList { ["operation"] = operation, ["success"] = success });
        _azureApiDuration.Record(duration, new TagList { ["operation"] = operation });
    }
}
```

## 📈 Monitoring Dashboard Queries

### Azure API Health Monitoring
```kusto
// Application Insights - Azure API failure rates
dependencies
| where name startswith "Azure"
| summarize 
    TotalCalls = count(),
    FailureRate = countif(success == false) * 100.0 / count(),
    AvgDuration = avg(duration)
by name, bin(timestamp, 5m)
| render timechart
```

### Dapr Service Communication Health
```kusto
// Dapr service invocation success rates
traces
| where customDimensions.["dapr.operation"] == "service_invocation"
| summarize 
    Calls = count(),
    Failures = countif(customDimensions.["dapr.status"] != "success")
by tostring(customDimensions.["dapr.target_app"]), bin(timestamp, 1m)
```

## 🚀 Migration Strategy

### Week 1: Infrastructure Prep
- [ ] Update Bicep templates with Dapr configuration
- [ ] Deploy Dapr-enabled Container Apps Environment
- [ ] Add Dapr NuGet packages to Portal and DAB

### Week 2: Basic Integration
- [ ] Replace HttpClient calls with DaprClient
- [ ] Add distributed tracing
- [ ] Implement basic retry policies

### Week 3: Advanced Features
- [ ] Add state management for caching
- [ ] Implement secrets management
- [ ] Set up custom metrics

### Week 4: Event-Driven Features
- [ ] Add pub/sub for infrastructure changes
- [ ] Implement real-time UI updates
- [ ] Add comprehensive monitoring dashboards

## 💡 Immediate Debug Wins

With Dapr enabled, you'll immediately get:
1. **Automatic distributed tracing** across Portal → DAB → Azure APIs
2. **Detailed logs** showing exact Azure SDK authentication flows
3. **Health endpoints** for each service dependency
4. **Automatic retries** for transient Azure API failures
5. **Circuit breakers** preventing cascade failures
6. **Metrics** on Azure API performance and reliability
