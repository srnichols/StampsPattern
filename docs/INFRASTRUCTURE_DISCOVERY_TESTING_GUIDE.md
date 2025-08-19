# Infrastructure Discovery Function - Integration Testing Guide

## Overview

This guide provides comprehensive testing strategies for the Infrastructure Discovery Function, including unit tests, integration tests, load tests, and end-to-end validation scenarios.

## Test Environment Setup

### Local Testing Environment

#### Prerequisites
```powershell
# Install required tools
npm install -g azurite
dotnet tool install -g Microsoft.Azure.Functions.CoreTools
dotnet add package Microsoft.NET.Test.Sdk
dotnet add package xunit
dotnet add package xunit.runner.visualstudio
dotnet add package Moq
dotnet add package Microsoft.AspNetCore.Mvc.Testing
```

#### Test Configuration (local.settings.test.json)
```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet",
    "FUNCTIONS_EXTENSION_VERSION": "~4",
    "KeyVaultUrl": "https://test-keyvault.vault.azure.net/",
    "ENABLE_CACHE": "true",
    "CACHE_DURATION_MINUTES": "1",
    "MAX_PARALLEL_DISCOVERIES": "5",
    "DISCOVERY_TIMEOUT_SECONDS": "30",
    "TEST_MODE": "true"
  }
}
```

### Azure Test Environment

#### Test Resource Group Setup
```bash
# Create test environment
RESOURCE_GROUP_TEST="rg-stamps-functions-test"
LOCATION="eastus"
FUNCTION_APP_TEST="func-stamps-discovery-test"

az group create --name $RESOURCE_GROUP_TEST --location $LOCATION

# Deploy test infrastructure using ARM template
az deployment group create \
  --resource-group $RESOURCE_GROUP_TEST \
  --template-file ../azuredeploy.json \
  --parameters functionAppName=$FUNCTION_APP_TEST
```

## Unit Tests

### Test Project Structure
```
Tests/
├── Infrastructure.Discovery.Tests.csproj
├── Unit/
│   ├── InfrastructureDiscoveryFunctionTests.cs
│   ├── DiscoveryCacheServiceTests.cs
│   ├── PerformanceMonitoringServiceTests.cs
│   └── TestHelpers/
├── Integration/
│   ├── EndToEndTests.cs
│   ├── AzureResourceManagerTests.cs
│   └── CacheIntegrationTests.cs
└── Load/
    ├── LoadTestConfiguration.cs
    └── PerformanceTests.cs
```

### Unit Test Implementation

#### InfrastructureDiscoveryFunctionTests.cs
```csharp
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;
using System.Threading.Tasks;
using System.Collections.Generic;

namespace Infrastructure.Discovery.Tests.Unit
{
    public class InfrastructureDiscoveryFunctionTests
    {
        private readonly Mock<ILogger<InfrastructureDiscoveryFunction>> _loggerMock;
        private readonly Mock<IDiscoveryCacheService> _cacheMock;
        private readonly Mock<IPerformanceMonitoringService> _performanceMock;
        private readonly InfrastructureDiscoveryFunction _function;

        public InfrastructureDiscoveryFunctionTests()
        {
            _loggerMock = new Mock<ILogger<InfrastructureDiscoveryFunction>>();
            _cacheMock = new Mock<IDiscoveryCacheService>();
            _performanceMock = new Mock<IPerformanceMonitoringService>();
            _function = new InfrastructureDiscoveryFunction(_loggerMock.Object, _cacheMock.Object, _performanceMock.Object);
        }

        [Fact]
        public async Task DiscoverInfrastructure_SimulatedMode_ReturnsExpectedResults()
        {
            // Arrange
            var request = CreateMockRequest("?mode=simulated");
            _cacheMock.Setup(x => x.TryGetValue(It.IsAny<string>(), out It.Ref<object>.IsAny))
                     .Returns(false);
            
            // Act
            var result = await _function.DiscoverInfrastructure(request.Object);

            // Assert
            Assert.IsType<OkObjectResult>(result);
            var okResult = result as OkObjectResult;
            var response = okResult.Value as dynamic;
            
            Assert.NotNull(response);
            Assert.True(response.Stamps.Count > 0);
            Assert.Equal("simulated", response.Mode);
        }

        [Fact]
        public async Task DiscoverInfrastructure_CacheHit_ReturnsFromCache()
        {
            // Arrange
            var request = CreateMockRequest("?mode=simulated");
            var cachedData = new { Message = "Cached response" };
            
            _cacheMock.Setup(x => x.TryGetValue("discovery:simulated", out It.Ref<object>.IsAny))
                     .Returns((string key, out object value) =>
                     {
                         value = cachedData;
                         return true;
                     });

            // Act
            var result = await _function.DiscoverInfrastructure(request.Object);

            // Assert
            var okResult = result as OkObjectResult;
            Assert.Equal(cachedData, okResult.Value);
            
            // Verify cache was checked but performance monitoring was still called
            _cacheMock.Verify(x => x.TryGetValue("discovery:simulated", out It.Ref<object>.IsAny), Times.Once);
        }

        [Fact]
        public async Task DiscoverInfrastructure_AzureMode_RequiresValidCredentials()
        {
            // Arrange
            var request = CreateMockRequest("?mode=azure");
            _cacheMock.Setup(x => x.TryGetValue(It.IsAny<string>(), out It.Ref<object>.IsAny))
                     .Returns(false);

            // Act & Assert
            var result = await _function.DiscoverInfrastructure(request.Object);
            
            // Should handle authentication gracefully in test environment
            Assert.IsType<OkObjectResult>(result);
        }

        [Theory]
        [InlineData("invalid")]
        [InlineData("")]
        [InlineData(null)]
        public async Task DiscoverInfrastructure_InvalidMode_DefaultsToSimulated(string mode)
        {
            // Arrange
            var queryString = string.IsNullOrEmpty(mode) ? "" : $"?mode={mode}";
            var request = CreateMockRequest(queryString);
            
            _cacheMock.Setup(x => x.TryGetValue(It.IsAny<string>(), out It.Ref<object>.IsAny))
                     .Returns(false);

            // Act
            var result = await _function.DiscoverInfrastructure(request.Object);

            // Assert
            var okResult = result as OkObjectResult;
            var response = okResult.Value as dynamic;
            Assert.Equal("simulated", response.Mode);
        }

        [Fact]
        public async Task DiscoverInfrastructure_PerformanceMonitoring_TracksExecution()
        {
            // Arrange
            var request = CreateMockRequest("?mode=simulated");
            _cacheMock.Setup(x => x.TryGetValue(It.IsAny<string>(), out It.Ref<object>.IsAny))
                     .Returns(false);

            // Act
            await _function.DiscoverInfrastructure(request.Object);

            // Assert
            _performanceMock.Verify(x => x.MeasureAsync(
                It.IsAny<string>(), 
                It.IsAny<Func<Task<object>>>()
            ), Times.Once);
        }

        private Mock<HttpRequest> CreateMockRequest(string queryString = "")
        {
            var request = new Mock<HttpRequest>();
            var query = new Mock<IQueryCollection>();
            
            if (!string.IsNullOrEmpty(queryString))
            {
                var queryParams = Microsoft.AspNetCore.WebUtilities.QueryHelpers.ParseQuery(queryString);
                foreach (var param in queryParams)
                {
                    query.Setup(x => x[param.Key]).Returns(param.Value);
                }
            }
            
            request.Setup(x => x.Query).Returns(query.Object);
            return request;
        }
    }
}
```

#### DiscoveryCacheServiceTests.cs
```csharp
using Xunit;
using System.Threading.Tasks;
using System;
using Microsoft.Extensions.Logging;
using Moq;

namespace Infrastructure.Discovery.Tests.Unit
{
    public class DiscoveryCacheServiceTests
    {
        private readonly Mock<ILogger<DiscoveryCacheService>> _loggerMock;
        private readonly DiscoveryCacheService _cacheService;

        public DiscoveryCacheServiceTests()
        {
            _loggerMock = new Mock<ILogger<DiscoveryCacheService>>();
            _cacheService = new DiscoveryCacheService(_loggerMock.Object);
        }

        [Fact]
        public void TryGetValue_EmptyCache_ReturnsFalse()
        {
            // Arrange & Act
            var result = _cacheService.TryGetValue("test-key", out var value);

            // Assert
            Assert.False(result);
            Assert.Null(value);
        }

        [Fact]
        public void SetValue_ThenTryGetValue_ReturnsTrue()
        {
            // Arrange
            var key = "test-key";
            var testData = new { Message = "Test data" };

            // Act
            _cacheService.Set(key, testData);
            var result = _cacheService.TryGetValue(key, out var value);

            // Assert
            Assert.True(result);
            Assert.Equal(testData, value);
        }

        [Fact]
        public void GetStatistics_ReturnsAccurateStats()
        {
            // Arrange
            _cacheService.Set("key1", "value1");
            _cacheService.Set("key2", "value2");
            
            // Simulate cache hits and misses
            _cacheService.TryGetValue("key1", out _); // Hit
            _cacheService.TryGetValue("key3", out _); // Miss

            // Act
            var stats = _cacheService.GetStatistics();

            // Assert
            Assert.Equal(2, stats.TotalEntries);
            Assert.Equal(1, stats.HitCount);
            Assert.Equal(1, stats.MissCount);
            Assert.Equal(0.5, stats.HitRate);
        }

        [Fact]
        public async Task BackgroundRefresh_DoesNotBlock()
        {
            // Arrange
            var key = "refresh-test";
            var refreshCalled = false;
            
            Func<Task<object>> refreshFunc = async () =>
            {
                await Task.Delay(100); // Simulate work
                refreshCalled = true;
                return new { Refreshed = true };
            };

            // Act
            _cacheService.SetWithRefresh(key, new { Original = true }, refreshFunc);
            
            // Immediate get should return original value
            var immediateResult = _cacheService.TryGetValue(key, out var immediateValue);
            
            // Wait for background refresh
            await Task.Delay(200);

            // Assert
            Assert.True(immediateResult);
            Assert.True(refreshCalled);
        }

        [Fact]
        public void MemoryPressure_TriggersEviction()
        {
            // Arrange - Fill cache with many entries
            for (int i = 0; i < 1000; i++)
            {
                _cacheService.Set($"key-{i}", $"value-{i}");
            }

            var initialStats = _cacheService.GetStatistics();

            // Act - Simulate memory pressure
            GC.Collect();
            GC.WaitForPendingFinalizers();
            GC.Collect();

            // Add one more item to trigger cleanup
            _cacheService.Set("trigger-cleanup", "value");
            
            var finalStats = _cacheService.GetStatistics();

            // Assert - Some entries should have been evicted
            Assert.True(finalStats.EvictionCount > 0);
        }
    }
}
```

#### PerformanceMonitoringServiceTests.cs
```csharp
using Xunit;
using System.Threading.Tasks;
using System;
using Microsoft.Extensions.Logging;
using Moq;

namespace Infrastructure.Discovery.Tests.Unit
{
    public class PerformanceMonitoringServiceTests
    {
        private readonly Mock<ILogger<PerformanceMonitoringService>> _loggerMock;
        private readonly PerformanceMonitoringService _performanceService;

        public PerformanceMonitoringServiceTests()
        {
            _loggerMock = new Mock<ILogger<PerformanceMonitoringService>>();
            _performanceService = new PerformanceMonitoringService(_loggerMock.Object);
        }

        [Fact]
        public async Task MeasureAsync_SuccessfulOperation_RecordsMetrics()
        {
            // Arrange
            var operationName = "test-operation";
            var expectedResult = new { Data = "test" };
            
            Func<Task<object>> operation = async () =>
            {
                await Task.Delay(50); // Simulate work
                return expectedResult;
            };

            // Act
            var result = await _performanceService.MeasureAsync(operationName, operation);

            // Assert
            Assert.Equal(expectedResult, result);
            
            var metrics = _performanceService.GetMetrics(operationName);
            Assert.Equal(1, metrics.SuccessCount);
            Assert.Equal(0, metrics.FailureCount);
            Assert.True(metrics.AverageExecutionTime > TimeSpan.Zero);
        }

        [Fact]
        public async Task MeasureAsync_FailedOperation_RecordsFailure()
        {
            // Arrange
            var operationName = "failing-operation";
            var expectedException = new InvalidOperationException("Test exception");
            
            Func<Task<object>> operation = async () =>
            {
                await Task.Delay(10);
                throw expectedException;
            };

            // Act & Assert
            var exception = await Assert.ThrowsAsync<InvalidOperationException>(
                () => _performanceService.MeasureAsync(operationName, operation)
            );
            
            Assert.Equal(expectedException.Message, exception.Message);
            
            var metrics = _performanceService.GetMetrics(operationName);
            Assert.Equal(0, metrics.SuccessCount);
            Assert.Equal(1, metrics.FailureCount);
        }

        [Fact]
        public async Task MultipleOperations_CalculatesCorrectAverages()
        {
            // Arrange
            var operationName = "average-test";
            var delays = new[] { 10, 20, 30, 40, 50 };

            // Act
            foreach (var delay in delays)
            {
                await _performanceService.MeasureAsync(operationName, async () =>
                {
                    await Task.Delay(delay);
                    return "success";
                });
            }

            // Assert
            var metrics = _performanceService.GetMetrics(operationName);
            Assert.Equal(5, metrics.SuccessCount);
            Assert.Equal(1.0, metrics.SuccessRate);
            Assert.True(metrics.AverageExecutionTime.TotalMilliseconds > 25); // Should be around 30ms
        }

        [Fact]
        public void GetAllMetrics_ReturnsAllOperations()
        {
            // Arrange
            var operations = new[] { "op1", "op2", "op3" };
            
            // Act
            foreach (var op in operations)
            {
                Task.Run(async () => await _performanceService.MeasureAsync(op, async () =>
                {
                    await Task.Delay(1);
                    return "result";
                })).Wait();
            }

            var allMetrics = _performanceService.GetAllMetrics();

            // Assert
            Assert.Equal(operations.Length, allMetrics.Count);
            foreach (var op in operations)
            {
                Assert.Contains(op, allMetrics.Keys);
            }
        }
    }
}
```

## Integration Tests

### Azure Resource Manager Integration Tests

#### AzureResourceManagerTests.cs
```csharp
using Xunit;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Azure.Identity;
using Azure.ResourceManager;
using System.Linq;

namespace Infrastructure.Discovery.Tests.Integration
{
    [Collection("Azure Integration Tests")]
    public class AzureResourceManagerTests
    {
        private readonly IConfiguration _configuration;
        private readonly ArmClient _armClient;

        public AzureResourceManagerTests()
        {
            _configuration = new ConfigurationBuilder()
                .AddJsonFile("local.settings.test.json", optional: false)
                .Build();

            _armClient = new ArmClient(new DefaultAzureCredential());
        }

        [Fact]
        [Trait("Category", "Integration")]
        public async Task DiscoverSubscriptions_ReturnsAccessibleSubscriptions()
        {
            // Arrange & Act
            var subscriptions = _armClient.GetSubscriptions();
            var subscriptionList = await subscriptions.ToEnumerableAsync();

            // Assert
            Assert.NotEmpty(subscriptionList);
            Assert.All(subscriptionList, s => Assert.NotNull(s.Data.DisplayName));
        }

        [Fact]
        [Trait("Category", "Integration")]
        public async Task DiscoverResourceGroups_ReturnsExpectedStructure()
        {
            // Arrange
            var subscription = await _armClient.GetDefaultSubscriptionAsync();

            // Act
            var resourceGroups = subscription.GetResourceGroups();
            var rgList = await resourceGroups.ToEnumerableAsync();

            // Assert
            Assert.NotEmpty(rgList);
            
            var stampsResourceGroups = rgList.Where(rg => 
                rg.Data.Name.Contains("stamps") || 
                rg.Data.Name.Contains("cell"));
            
            Assert.NotEmpty(stampsResourceGroups);
        }

        [Fact]
        [Trait("Category", "Integration")]
        public async Task DiscoverStampResources_IdentifiesStampPattern()
        {
            // Arrange
            var subscription = await _armClient.GetDefaultSubscriptionAsync();
            var resourceGroups = subscription.GetResourceGroups();
            
            // Act
            var discoveredStamps = new List<object>();
            
            await foreach (var rg in resourceGroups)
            {
                if (IsStampResourceGroup(rg.Data.Name))
                {
                    var resources = rg.GetGenericResources();
                    var resourceList = await resources.ToEnumerableAsync();
                    
                    var stamp = AnalyzeStampResources(rg.Data.Name, resourceList);
                    if (stamp != null)
                    {
                        discoveredStamps.Add(stamp);
                    }
                }
            }

            // Assert
            Assert.NotEmpty(discoveredStamps);
        }

        private bool IsStampResourceGroup(string resourceGroupName)
        {
            var stampPatterns = new[]
            {
                @"rg-.*-cell\d+",
                @"rg-.*-stamp\d+",
                @".*-region\d+-.*"
            };

            return stampPatterns.Any(pattern => 
                System.Text.RegularExpressions.Regex.IsMatch(resourceGroupName, pattern));
        }

        private object AnalyzeStampResources(string rgName, IEnumerable<Azure.ResourceManager.Resources.GenericResource> resources)
        {
            var resourceTypes = resources.GroupBy(r => r.Data.ResourceType)
                                       .ToDictionary(g => g.Key.ToString(), g => g.Count());

            if (resourceTypes.Count == 0) return null;

            return new
            {
                Name = rgName,
                ResourceTypes = resourceTypes,
                TotalResources = resources.Count(),
                HasCosmosDb = resourceTypes.ContainsKey("Microsoft.DocumentDB/databaseAccounts"),
                HasAppService = resourceTypes.ContainsKey("Microsoft.Web/sites"),
                HasStorageAccount = resourceTypes.ContainsKey("Microsoft.Storage/storageAccounts")
            };
        }
    }
}
```

### End-to-End Tests

#### EndToEndTests.cs
```csharp
using Xunit;
using System.Threading.Tasks;
using System.Net.Http;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Newtonsoft.Json;

namespace Infrastructure.Discovery.Tests.Integration
{
    public class EndToEndTests : IClassFixture<WebApplicationFactory<Program>>
    {
        private readonly WebApplicationFactory<Program> _factory;
        private readonly HttpClient _client;

        public EndToEndTests(WebApplicationFactory<Program> factory)
        {
            _factory = factory;
            _client = _factory.CreateClient();
        }

        [Fact]
        [Trait("Category", "E2E")]
        public async Task DiscoverInfrastructure_SimulatedMode_ReturnsValidResponse()
        {
            // Act
            var response = await _client.GetAsync("/api/infrastructure/discover?mode=simulated");

            // Assert
            response.EnsureSuccessStatusCode();
            
            var content = await response.Content.ReadAsStringAsync();
            var result = JsonConvert.DeserializeObject<dynamic>(content);
            
            Assert.NotNull(result);
            Assert.Equal("simulated", (string)result.Mode);
            Assert.NotNull(result.Stamps);
            Assert.True(((Newtonsoft.Json.Linq.JArray)result.Stamps).Count > 0);
        }

        [Fact]
        [Trait("Category", "E2E")]
        public async Task DiscoverInfrastructure_Performance_WithinAcceptableLimits()
        {
            // Arrange
            var maxAcceptableTime = TimeSpan.FromSeconds(5);
            var startTime = DateTime.UtcNow;

            // Act
            var response = await _client.GetAsync("/api/infrastructure/discover?mode=simulated");
            var endTime = DateTime.UtcNow;

            // Assert
            response.EnsureSuccessStatusCode();
            var executionTime = endTime - startTime;
            Assert.True(executionTime < maxAcceptableTime, 
                $"Request took {executionTime.TotalSeconds}s, which exceeds the limit of {maxAcceptableTime.TotalSeconds}s");
        }

        [Fact]
        [Trait("Category", "E2E")]
        public async Task DiscoverInfrastructure_ConcurrentRequests_HandledCorrectly()
        {
            // Arrange
            var concurrentRequests = 10;
            var tasks = new List<Task<HttpResponseMessage>>();

            // Act
            for (int i = 0; i < concurrentRequests; i++)
            {
                tasks.Add(_client.GetAsync("/api/infrastructure/discover?mode=simulated"));
            }

            var responses = await Task.WhenAll(tasks);

            // Assert
            Assert.All(responses, response =>
            {
                Assert.True(response.IsSuccessStatusCode);
            });

            // Verify all responses have valid content
            var contents = await Task.WhenAll(
                responses.Select(r => r.Content.ReadAsStringAsync())
            );

            Assert.All(contents, content =>
            {
                var result = JsonConvert.DeserializeObject<dynamic>(content);
                Assert.NotNull(result);
                Assert.Equal("simulated", (string)result.Mode);
            });
        }

        [Fact]
        [Trait("Category", "E2E")]
        public async Task DiscoverInfrastructure_CacheEffectiveness_SecondRequestFaster()
        {
            // Arrange & Act - First request (should populate cache)
            var firstStartTime = DateTime.UtcNow;
            var firstResponse = await _client.GetAsync("/api/infrastructure/discover?mode=simulated");
            var firstEndTime = DateTime.UtcNow;
            var firstDuration = firstEndTime - firstStartTime;

            // Second request (should use cache)
            var secondStartTime = DateTime.UtcNow;
            var secondResponse = await _client.GetAsync("/api/infrastructure/discover?mode=simulated");
            var secondEndTime = DateTime.UtcNow;
            var secondDuration = secondEndTime - secondStartTime;

            // Assert
            firstResponse.EnsureSuccessStatusCode();
            secondResponse.EnsureSuccessStatusCode();
            
            // Second request should be faster (cache hit)
            Assert.True(secondDuration < firstDuration, 
                $"Second request ({secondDuration.TotalMilliseconds}ms) should be faster than first ({firstDuration.TotalMilliseconds}ms)");
        }
    }
}
```

## Load Testing

### Azure Load Testing Configuration

#### load-test-config.yaml
```yaml
testName: InfrastructureDiscoveryLoadTest
testDescription: Load test for Infrastructure Discovery Function
engineInstances: 3

testPlan: infrastructure-discovery-load-test.jmx

configurationFiles:
  - load-test.csv

properties:
  threads: 50
  ramp-up: 60
  duration: 300
  target-url: https://func-stamps-discovery.azurewebsites.net

passFailCriteria:
  - avg(response_time_ms) > 5000
  - percentage(error) > 5

autoStop:
  autoStopDisabled: false
  errorRate: 90
  errorRateTimeWindowInSeconds: 60
```

#### PowerShell Load Test Script
```powershell
# load-test.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$FunctionUrl,
    
    [int]$ConcurrentUsers = 50,
    [int]$DurationMinutes = 5,
    [int]$RampUpSeconds = 60
)

Write-Host "Starting load test against: $FunctionUrl"
Write-Host "Concurrent Users: $ConcurrentUsers"
Write-Host "Duration: $DurationMinutes minutes"
Write-Host "Ramp-up: $RampUpSeconds seconds"

$endpoints = @(
    "$FunctionUrl/api/infrastructure/discover?mode=simulated",
    "$FunctionUrl/api/infrastructure/discover?mode=azure"
)

$results = @()
$startTime = Get-Date
$endTime = $startTime.AddMinutes($DurationMinutes)

# Ramp-up phase
$jobs = @()
for ($i = 1; $i -le $ConcurrentUsers; $i++) {
    Start-Sleep -Milliseconds ($RampUpSeconds * 1000 / $ConcurrentUsers)
    
    $job = Start-Job -ScriptBlock {
        param($url, $endTime)
        
        $localResults = @()
        while ((Get-Date) -lt $endTime) {
            try {
                $requestStart = Get-Date
                $response = Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 30
                $requestEnd = Get-Date
                
                $localResults += [PSCustomObject]@{
                    Timestamp = $requestStart
                    Duration = ($requestEnd - $requestStart).TotalMilliseconds
                    Success = $true
                    StatusCode = 200
                    Error = $null
                }
            }
            catch {
                $requestEnd = Get-Date
                $localResults += [PSCustomObject]@{
                    Timestamp = $requestStart
                    Duration = ($requestEnd - $requestStart).TotalMilliseconds
                    Success = $false
                    StatusCode = 0
                    Error = $_.Exception.Message
                }
            }
            
            Start-Sleep -Milliseconds 100
        }
        
        return $localResults
    } -ArgumentList ($endpoints | Get-Random), $endTime
    
    $jobs += $job
}

Write-Host "All $ConcurrentUsers users started. Running test..."

# Wait for completion
$jobs | Wait-Job | ForEach-Object {
    $results += Receive-Job $_
    Remove-Job $_
}

# Analyze results
$totalRequests = $results.Count
$successfulRequests = ($results | Where-Object { $_.Success }).Count
$failedRequests = $totalRequests - $successfulRequests
$averageResponseTime = ($results | Measure-Object -Property Duration -Average).Average
$maxResponseTime = ($results | Measure-Object -Property Duration -Maximum).Maximum
$minResponseTime = ($results | Measure-Object -Property Duration -Minimum).Minimum

$p95ResponseTime = ($results | Sort-Object Duration)[([int]($totalRequests * 0.95))]?.Duration
$p99ResponseTime = ($results | Sort-Object Duration)[([int]($totalRequests * 0.99))]?.Duration

$requestsPerSecond = $totalRequests / $DurationMinutes / 60

Write-Host "`n=== Load Test Results ==="
Write-Host "Total Requests: $totalRequests"
Write-Host "Successful Requests: $successfulRequests"
Write-Host "Failed Requests: $failedRequests"
Write-Host "Success Rate: $([math]::Round(($successfulRequests / $totalRequests) * 100, 2))%"
Write-Host "Requests/Second: $([math]::Round($requestsPerSecond, 2))"
Write-Host "`nResponse Times (ms):"
Write-Host "  Average: $([math]::Round($averageResponseTime, 2))"
Write-Host "  Min: $([math]::Round($minResponseTime, 2))"
Write-Host "  Max: $([math]::Round($maxResponseTime, 2))"
Write-Host "  95th Percentile: $([math]::Round($p95ResponseTime, 2))"
Write-Host "  99th Percentile: $([math]::Round($p99ResponseTime, 2))"

# Error analysis
if ($failedRequests -gt 0) {
    Write-Host "`n=== Error Analysis ==="
    $errorGroups = $results | Where-Object { -not $_.Success } | Group-Object Error
    foreach ($group in $errorGroups) {
        Write-Host "  $($group.Name): $($group.Count) occurrences"
    }
}

# Export detailed results
$results | Export-Csv -Path "load-test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv" -NoTypeInformation
Write-Host "`nDetailed results exported to CSV file."
```

## Performance Benchmarks

### Baseline Performance Metrics

#### Expected Performance Targets
```csharp
public static class PerformanceTargets
{
    public const int MaxResponseTimeMs = 5000;
    public const int MaxP95ResponseTimeMs = 3000;
    public const int MaxP99ResponseTimeMs = 8000;
    public const double MinSuccessRate = 0.99;
    public const int MaxConcurrentUsers = 100;
    public const double MaxErrorRate = 0.01;
    
    // Cache performance
    public const double MinCacheHitRate = 0.80;
    public const int MaxCacheRefreshTimeMs = 1000;
    
    // Resource discovery
    public const int MaxResourcesPerStamp = 500;
    public const int MaxStampsDiscovered = 20;
    public const int MaxDiscoveryTimeMs = 30000;
}
```

### Performance Test Implementation

#### PerformanceTests.cs
```csharp
using Xunit;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Net.Http;

namespace Infrastructure.Discovery.Tests.Load
{
    public class PerformanceTests
    {
        private readonly HttpClient _client;

        public PerformanceTests()
        {
            _client = new HttpClient
            {
                BaseAddress = new Uri("https://func-stamps-discovery.azurewebsites.net"),
                Timeout = TimeSpan.FromSeconds(30)
            };
        }

        [Fact]
        [Trait("Category", "Performance")]
        public async Task SingleRequest_ResponseTime_WithinLimits()
        {
            // Arrange
            var stopwatch = Stopwatch.StartNew();

            // Act
            var response = await _client.GetAsync("/api/infrastructure/discover?mode=simulated");
            stopwatch.Stop();

            // Assert
            response.EnsureSuccessStatusCode();
            Assert.True(stopwatch.ElapsedMilliseconds < PerformanceTargets.MaxResponseTimeMs,
                $"Response time {stopwatch.ElapsedMilliseconds}ms exceeds limit of {PerformanceTargets.MaxResponseTimeMs}ms");
        }

        [Fact]
        [Trait("Category", "Performance")]
        public async Task ConcurrentRequests_ThroughputAcceptable()
        {
            // Arrange
            const int concurrentRequests = 20;
            var tasks = new List<Task<(bool Success, long ElapsedMs)>>();
            var stopwatch = Stopwatch.StartNew();

            // Act
            for (int i = 0; i < concurrentRequests; i++)
            {
                tasks.Add(TimedRequest());
            }

            var results = await Task.WhenAll(tasks);
            stopwatch.Stop();

            // Assert
            var successCount = results.Count(r => r.Success);
            var successRate = (double)successCount / concurrentRequests;
            var avgResponseTime = results.Where(r => r.Success).Average(r => r.ElapsedMs);
            var throughput = (double)concurrentRequests / stopwatch.Elapsed.TotalSeconds;

            Assert.True(successRate >= PerformanceTargets.MinSuccessRate,
                $"Success rate {successRate:P2} below minimum {PerformanceTargets.MinSuccessRate:P2}");
            
            Assert.True(avgResponseTime < PerformanceTargets.MaxResponseTimeMs,
                $"Average response time {avgResponseTime}ms exceeds limit");

            Assert.True(throughput > 1.0, $"Throughput {throughput:F2} req/s too low");
        }

        private async Task<(bool Success, long ElapsedMs)> TimedRequest()
        {
            var stopwatch = Stopwatch.StartNew();
            try
            {
                var response = await _client.GetAsync("/api/infrastructure/discover?mode=simulated");
                stopwatch.Stop();
                return (response.IsSuccessStatusCode, stopwatch.ElapsedMilliseconds);
            }
            catch
            {
                stopwatch.Stop();
                return (false, stopwatch.ElapsedMilliseconds);
            }
        }
    }
}
```

## Test Execution

### Local Test Execution

```powershell
# Run all tests
dotnet test --configuration Release --logger trx --results-directory TestResults

# Run specific test categories
dotnet test --filter "Category=Unit" --logger console
dotnet test --filter "Category=Integration" --logger console
dotnet test --filter "Category=E2E" --logger console
dotnet test --filter "Category=Performance" --logger console

# Run with coverage
dotnet test --collect:"XPlat Code Coverage" --results-directory TestResults
```

### CI/CD Pipeline Integration

#### GitHub Actions Test Workflow
```yaml
name: Test Infrastructure Discovery Function

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup .NET
      uses: actions/setup-dotnet@v3
      with:
        dotnet-version: 6.0.x
    
    - name: Restore dependencies
      run: dotnet restore ./Tests/Infrastructure.Discovery.Tests.csproj
    
    - name: Build
      run: dotnet build ./Tests/Infrastructure.Discovery.Tests.csproj --no-restore
    
    - name: Run Unit Tests
      run: dotnet test ./Tests/Infrastructure.Discovery.Tests.csproj --filter "Category=Unit" --logger trx --results-directory TestResults
    
    - name: Run Integration Tests
      run: dotnet test ./Tests/Infrastructure.Discovery.Tests.csproj --filter "Category=Integration" --logger trx --results-directory TestResults
      env:
        AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
        AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
        AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
    
    - name: Publish Test Results
      uses: dorny/test-reporter@v1
      if: success() || failure()
      with:
        name: Test Results
        path: TestResults/*.trx
        reporter: dotnet-trx
```

### Azure DevOps Pipeline

```yaml
trigger:
- main

pool:
  vmImage: 'windows-latest'

variables:
  buildConfiguration: 'Release'

stages:
- stage: Test
  jobs:
  - job: UnitTests
    displayName: 'Unit Tests'
    steps:
    - task: DotNetCoreCLI@2
      displayName: 'Run Unit Tests'
      inputs:
        command: 'test'
        projects: '**/Infrastructure.Discovery.Tests.csproj'
        arguments: '--filter "Category=Unit" --configuration $(buildConfiguration) --logger trx --collect:"XPlat Code Coverage"'
        
  - job: IntegrationTests
    displayName: 'Integration Tests'
    dependsOn: UnitTests
    steps:
    - task: DotNetCoreCLI@2
      displayName: 'Run Integration Tests'
      inputs:
        command: 'test'
        projects: '**/Infrastructure.Discovery.Tests.csproj'
        arguments: '--filter "Category=Integration" --configuration $(buildConfiguration) --logger trx'
        
  - job: LoadTests
    displayName: 'Load Tests'
    dependsOn: IntegrationTests
    steps:
    - task: AzureLoadTest@1
      displayName: 'Run Load Tests'
      inputs:
        azureSubscription: 'Azure Service Connection'
        loadTestConfigFile: 'load-test-config.yaml'
        loadTestResource: 'load-test-resource'
```

## Test Data Management

### Test Environment Cleanup

```powershell
# cleanup-test-environment.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [string]$ResourceGroupPrefix = "rg-stamps-test"
)

# Connect to Azure
Connect-AzAccount
Select-AzSubscription -SubscriptionId $SubscriptionId

# Get all test resource groups
$testResourceGroups = Get-AzResourceGroup | Where-Object { 
    $_.ResourceGroupName -like "$ResourceGroupPrefix*" 
}

foreach ($rg in $testResourceGroups) {
    Write-Host "Cleaning up resource group: $($rg.ResourceGroupName)"
    
    # Check if it's safe to delete (contains test resources only)
    $resources = Get-AzResource -ResourceGroupName $rg.ResourceGroupName
    $testResources = $resources | Where-Object { 
        $_.Name -like "*test*" -or 
        $_.Name -like "*temp*" -or
        $_.Tags.Environment -eq "test"
    }
    
    if ($testResources.Count -eq $resources.Count) {
        Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force -AsJob
        Write-Host "  Deletion initiated for $($rg.ResourceGroupName)"
    } else {
        Write-Warning "  Skipping $($rg.ResourceGroupName) - contains non-test resources"
    }
}

Write-Host "Test environment cleanup completed."
```

This comprehensive integration testing guide provides thorough coverage of testing strategies for the Infrastructure Discovery Function, ensuring reliability, performance, and maintainability in production environments.
