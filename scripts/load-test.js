import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
export let errorRate = new Rate('errors');
export let responseTimes = new Trend('response_times');

// Test configuration
export let options = {
  // Ramp up to 100 virtual users over 2 minutes, maintain for 5 minutes, then ramp down
  stages: [
    { duration: '2m', target: 100 }, // Ramp up
    { duration: '5m', target: 100 }, // Maintain load
    { duration: '2m', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<200'], // 95% of requests must complete below 200ms
    http_req_failed: ['rate<0.1'],    // Error rate must be less than 10%
    errors: ['rate<0.1'],             // Custom error rate threshold
  },
};

// Base URL from environment variable or default
const BASE_URL = __ENV.TEST_URL || 'https://fa-stamps-eastus-dev.azurewebsites.net';

export default function () {
  // Test 1: Health Check Endpoint
  let healthResponse = http.get(`${BASE_URL}/api/health`);
  check(healthResponse, {
    'health check status is 200': (r) => r.status === 200,
    'health check response time < 100ms': (r) => r.timings.duration < 100,
  });
  errorRate.add(healthResponse.status !== 200);
  responseTimes.add(healthResponse.timings.duration);

  sleep(1);

  // Test 2: Get Tenant Info (Cached)
  let tenantInfoResponse = http.get(`${BASE_URL}/api/tenant/info?tenantId=test-tenant-${Math.floor(Math.random() * 1000)}`);
  check(tenantInfoResponse, {
    'tenant info status is 200 or 404': (r) => [200, 404].includes(r.status),
    'tenant info response time < 50ms': (r) => r.timings.duration < 50, // Should be fast due to caching
  });
  errorRate.add(![200, 404].includes(tenantInfoResponse.status));
  responseTimes.add(tenantInfoResponse.timings.duration);

  sleep(1);

  // Test 3: Create Tenant (Stress Test)
  let createTenantPayload = JSON.stringify({
    tenantId: `load-test-tenant-${Math.floor(Math.random() * 10000)}`,
    subdomain: `loadtest${Math.floor(Math.random() * 10000)}`,
    tenantTier: Math.random() > 0.7 ? 'Dedicated' : 'Shared', // 30% dedicated, 70% shared
    region: Math.random() > 0.5 ? 'eastus' : 'westus2',
    complianceRequirements: Math.random() > 0.8 ? ['HIPAA', 'SOC2'] : [],
  });

  let createTenantResponse = http.post(`${BASE_URL}/api/tenant`, createTenantPayload, {
    headers: {
      'Content-Type': 'application/json',
    },
  });

  check(createTenantResponse, {
    'create tenant status is 201': (r) => r.status === 201,
    'create tenant response time < 500ms': (r) => r.timings.duration < 500,
    'response contains cellId': (r) => r.json('cellId') !== undefined,
  });
  errorRate.add(createTenantResponse.status !== 201);
  responseTimes.add(createTenantResponse.timings.duration);

  sleep(2);

  // Test 4: JWT Validation Performance (Cached)
  let jwtTestResponse = http.get(`${BASE_URL}/api/tenant/cell?tenantId=test-tenant-jwt`, {
    headers: {
      'Authorization': 'Bearer test-jwt-token',
    },
  });

  check(jwtTestResponse, {
    'JWT validation response time < 20ms': (r) => r.timings.duration < 20, // Should be very fast with caching
  });
  responseTimes.add(jwtTestResponse.timings.duration);

  sleep(1);
}

// Teardown function to report final metrics
export function teardown(data) {
  console.log(`
  Load Test Summary:
  ==================
  - Total VUs: ${options.stages[1].target}
  - Test Duration: ${options.stages.reduce((sum, stage) => sum + parseInt(stage.duration), 0)} minutes
  - Expected Error Rate: < 10%
  - Expected P95 Response Time: < 200ms
  - JWT Validation Target: < 20ms (with caching)
  - Cache Hit Ratio Target: > 80%
  `);
}
