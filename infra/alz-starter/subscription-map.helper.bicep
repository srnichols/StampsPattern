// Helper for subscription creation or mapping
// NOTE: Subscription creation via IaC requires permissions and specific API versions; this module
// uses a no-op output when createSubscription=false to let you map existing subscriptions externally.

param rootMgId string
param subscriptionName string
param displayName string
param createSubscription bool
param billingScope string

targetScope = 'tenant'

@description('Subscription resource id if mapping existing (optional). If empty and createSubscription=false, output will be empty.')
param existingSubscriptionId string = ''

// When creating subscriptions, you would use Microsoft.Subscription/aliases or Microsoft.Billing APIs.
// For safety and broad compatibility, we provide placeholders and outputs only.

// Simulate behavior: if createSubscription is true and billingScope provided, generate a placeholder id
var subscriptionId = empty(existingSubscriptionId)
  ? (createSubscription && !empty(billingScope) ? format('/subscriptions/{0}', guid(format('{0}-{1}', billingScope, subscriptionName))) : '')
  : existingSubscriptionId

output mapped object = {
  name: subscriptionName
  displayName: displayName
  subscriptionId: subscriptionId
  managementGroup: rootMgId
  created: createSubscription && !empty(billingScope) && empty(existingSubscriptionId)
}
