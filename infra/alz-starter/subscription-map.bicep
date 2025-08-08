// Subscription map for ALZ-aligned environments (existing subscriptions only)
// Provide subscription IDs for platform/shared-services and cells; no creation occurs.

targetScope = 'tenant'

@description('Platform and shared services subscriptions (IDs required). Example keys: management, connectivity, sharedServices.')
param platform object = {
  // Example:
  // management: { subscriptionId: '/subscriptions/00000000-0000-0000-0000-000000000000' }
  // connectivity: { subscriptionId: '/subscriptions/11111111-1111-1111-1111-111111111111' }
  // sharedServices: { subscriptionId: '/subscriptions/22222222-2222-2222-2222-222222222222' }
}

@description('CELL subscriptions. Each item: { name: string, subscriptionId: string, displayName?: string }')
param cells array = []

// Outputs (pass-through for consumers to reference)
output platformSubscriptions object = platform
output cellSubscriptions array = cells
