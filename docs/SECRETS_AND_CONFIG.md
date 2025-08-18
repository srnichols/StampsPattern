# Secrets & Configuration (decision guide)

Purpose
- Quick decision tree and examples for secrets and configuration patterns used in this repo (P1 deliverable).

When to use which pattern

1) Container App secrets (fast, P0)
- Pros: Quick to set up, no external Key Vault dependency, easier for smoke/dev deployments.
- Cons: Secrets stored in Container App resource (less auditability), not recommended for production secrets.
- Use for: Demo secrets, local smoke runs, or temporary values while iterating.

2) Azure Key Vault + Managed Identity (recommended for production)
- Pros: Centralized secret management, RBAC and access logs, key rotation, soft-delete/recovery.
- Cons: Slightly more setup (Key Vault, access policy or RBAC), need to grant MI or SP access.
- Use for: Production connection strings, certificates, and any secret requiring audit/rotation.

Decision checklist
- Is this a production secret? → Use Key Vault + MI.
- Is the deployment short-lived or for local smoke? → Container App secret is acceptable.
- Do you need audit trail or rotation? → Key Vault.

Common env vars (Portal & DAB)

- Portal (management-portal/src/Portal)
  - `DAB_GRAPHQL_URL` — GraphQL endpoint for Data API Builder
  - `AzureAd__ClientId` / `AzureAd__TenantId` — AAD app settings for portal sign-in
  - `APPINSIGHTS_INSTRUMENTATIONKEY` — App Insights (or connection string variant)

- DAB (container image / dab-config.json)
  - `COSMOS_DB_CONNECTION` (if using connection string) or use Managed Identity
  - `DAB_LOG_LEVEL` — debug/info

Example: reference Key Vault secret from Bicep (container app)

```powershell
# In Bicep you can reference a key vault secret for container apps like this (pseudo):
# properties.configuration.secrets: [{ name: 'DAB_GRAPHQL_URL', value: keyVaultSecretUri }]

# In PowerShell/Az CLI you might set a secret value before deploying
az keyvault secret set --vault-name kv-stamps --name "DabGraphqlUrl" --value "https://ca-stamps-dab.internal/graphql"
```

Quick how-to: switch from container-app secret to Key Vault (high level)

1. Create Key Vault and add secret(s):

```powershell
az keyvault create -g rg-stamps-mgmt -n kv-stamps --location eastus
az keyvault secret set --vault-name kv-stamps --name "DabGraphqlUrl" --value "https://ca-stamps-dab.internal/graphql"
```

2. Grant the Container App managed identity access to Key Vault (get & list):

```powershell
# Get principal id of the container app's user-assigned or system identity
PRINCIPAL_ID=$(az resource show -g rg-stamps-mgmt -n ca-stamps-dab --resource-type Microsoft.App/containerApps --query identity.principalId -o tsv)
az keyvault set-policy -n kv-stamps --object-id $PRINCIPAL_ID --secret-permissions get list
```

3. Update Bicep to use `keyVaultReference` or set the secretRef in container-app configuration.

Operational notes
- Rotate secrets in Key Vault and re-deploy if references change. Prefer Key Vault references that the platform will resolve at runtime.
- For CI, use OIDC or a service principal with minimal access; store transient CI secrets in GitHub Secrets if absolutely needed.

Related docs
- `docs/LIVE_DATA_PATH.md` — quick checks for Portal → DAB → Cosmos
- `docs/AUTH_CI_STRATEGY.md` — auth patterns and CI notes
