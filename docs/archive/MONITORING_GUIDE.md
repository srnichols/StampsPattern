# 📊 Advanced Monitoring Setup - Complete Guide

## ✅ **Monitoring Components Deployed**

Your portal now has comprehensive monitoring configured:

### 🚨 **Alert Rules Active**

- **High Error Rate Alert**: Triggers when >5 failed requests in 15 minutes
- **High Response Time Alert**: Triggers when average response time >5 seconds

### 📈 **Monitoring URLs**

#### **Application Insights Dashboard**

```
https://portal.azure.com/#@16b3c013-d300-468d-ac64-7eda0820b6d3/resource/subscriptions/480cb033-9a92-4912-9d30-c6b7bf795a87/resourceGroups/rg-stamps-mgmt/providers/Microsoft.Insights/components/ai-xgjwtecm3g5pi/overview
```

#### **Log Analytics Logs**

```
https://portal.azure.com/#@16b3c013-d300-468d-ac64-7eda0820b6d3/resource/subscriptions/480cb033-9a92-4912-9d30-c6b7bf795a87/resourceGroups/rg-stamps-mgmt/providers/Microsoft.OperationalInsights/workspaces/law-xgjwtecm3g5pi/logs
```

## 📋 **Key Performance Indicators (KPIs) to Monitor**

### 1. **Application Performance**

- **Response Times**: Track P50, P95, P99 percentiles
- **Request Volume**: Monitor requests per minute/hour
- **Error Rate**: Track 4xx/5xx error percentages
- **Availability**: Monitor uptime percentage

### 2. **Business Metrics**

- **Tenant Onboarding Rate**: New tenants per day/week
- **Cell Utilization**: Resource usage across cells
- **Feature Adoption**: Usage of portal features
- **User Sessions**: Active users and session duration

### 3. **Infrastructure Metrics**

- **Container App Health**: CPU, Memory, Replica count
- **Cosmos DB Performance**: RU/s usage, query performance
- **Container Registry**: Image pull metrics

## 🔍 **Useful KQL Queries for Log Analytics**

### **Portal Request Analytics**

```kusto
AppRequests
| where TimeGenerated > ago(24h)
| summarize RequestCount = count(), 
          AvgDuration = avg(DurationMs),
          P95Duration = percentile(DurationMs, 95)
    by bin(TimeGenerated, 1h), ResultCode
| render timechart
```

### **Container App Logs**

```kusto
ContainerAppConsoleLogs_CL
| where ContainerAppName_s == "ca-stamps-portal"
| where TimeGenerated > ago(1h)
| project TimeGenerated, Log_s, LogLevel_s
| order by TimeGenerated desc
```

### **Error Analysis**

```kusto
AppExceptions
| where TimeGenerated > ago(24h)
| summarize ErrorCount = count() by Type, bin(TimeGenerated, 1h)
| render timechart
```

### **Tenant Operations Tracking**

```kusto
AppCustomEvents
| where TimeGenerated > ago(24h)
| where Name startswith "Tenant"
| summarize OperationCount = count() by Name, bin(TimeGenerated, 1h)
| render timechart
```

## 📊 **Custom Dashboards - Manual Setup**

### **Create Portal Performance Dashboard**

1. **Navigate to Azure Portal** → Dashboards → New Dashboard
2. **Add tiles for:**
   - Application Insights Overview
   - Request Volume Chart
   - Response Time Trends
   - Error Rate Monitor
   - Live Metrics

### **Key Metrics to Add:**

- **Requests per minute**
- **Average response time**
- **Failed request percentage**
- **Active users**
- **Exception count**

## 🔔 **Setting Up Alert Notifications**

### **Email Notifications**

```bash
# Add email notification to existing alerts
az monitor action-group create \
  --name "portal-alerts" \
  --resource-group "rg-stamps-mgmt" \
  --action email "admin@company.com" "Portal Admin"

# Link to existing alerts
az monitor metrics alert update \
  --name "alert-portal-high-error-rate" \
  --resource-group "rg-stamps-mgmt" \
  --add-action "/subscriptions/480cb033-9a92-4912-9d30-c6b7bf795a87/resourceGroups/rg-stamps-mgmt/providers/microsoft.insights/actionGroups/portal-alerts"
```

### **Teams/Slack Integration**

- Configure webhook actions in Action Groups
- Use Logic Apps for advanced notification workflows

## 🎯 **Monitoring Best Practices**

### **1. Proactive Monitoring**

- Set up alerts before issues occur
- Monitor trends, not just absolute values
- Use composite alerts for complex scenarios

### **2. Business Context**

- Track tenant-specific metrics
- Monitor feature usage patterns
- Correlate technical metrics with business KPIs

### **3. Performance Baselines**

- Establish normal performance ranges
- Track performance degradation over time
- Set alerts based on deviation from baseline

### **4. Cost Monitoring**

- Track Cosmos DB RU/s consumption
- Monitor Container App scaling patterns
- Set budget alerts for unexpected costs

## 🚀 **Next Level Monitoring**

### **Application Map**

- Visualize component dependencies
- Track cross-service performance
- Identify bottlenecks in request flow

### **Live Metrics**

- Real-time performance monitoring
- Live debugging capabilities
- Instant health assessment

### **Profiler & Snapshot Debugger**

- Deep performance analysis
- Production debugging
- Memory usage analysis

## 📈 **Success Metrics**

Your monitoring setup is successful when you can answer:

✅ **Is my portal healthy right now?**  
✅ **What's the user experience quality?**  
✅ **Are there any developing issues?**  
✅ **How are tenants using the platform?**  
✅ **What's my operational cost trend?**

---

## 🎉 **Your Portal is Production-Ready!**

You now have:

- **Secure Authentication** (Azure Entra ID ready)
- **Advanced Monitoring** (Alerts & Analytics)
- **Production Infrastructure** (Auto-scaling Container Apps)
- **Enterprise Security** (Managed identities & RBAC)

**Portal URL**: <https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io>

**Ready for the next phase of your multi-tenant SaaS journey!** 🚀
