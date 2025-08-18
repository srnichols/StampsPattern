# Secrets & Configuration (dev → prod)

This page lists the configuration and secret names used across the project, guidance for local development, and recommended Key Vault secret names for production.

Keep secrets out of source control. Use Azure Key Vault (recommended) for production and `local.settings.json` for local developer runs.

## Quick reference — key secrets & env vars

- COSMOS_CONN: Cosmos DB connection string (Key Vault secret: `secrets/cosmos-conn`)
- DAB_GRAPHQL_URL: Data API Builder GraphQL endpoint (set as app config / container env)
- DAB_CONFIG_BLOB or DAB_CONFIG_FILE: path to DAB configuration (if in-image)
- ACR_SERVER: ACR login server (e.g. `cr<...>.azurecr.io`)
- ACR_USERNAME / ACR_PASSWORD: use Managed Identity or service principal instead; prefer `az acr login` with MI
- KEY_VAULT_NAME: Key Vault which stores secrets for apps
- MI_CLIENT_ID / MSI_ENDPOINT: only for specialized local testing; prefer DefaultAzureCredential + Managed Identity in AKS/ContainerApps
- SEEDER_CLIENT_ID / SEEDER_TENANT_ID: for seeder when using service principal (optional)

## Local development

Use `local.settings.json` for Functions + DAB when running locally. Example minimal `local.settings.json`:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet",
    "COSMOS_CONN": "AccountEndpoint=https://<your-cosmos>.documents.azure.com:443/;AccountKey=<key>;",
    "DAB_GRAPHQL_URL": "http://localhost:5000/graphql"
  }
}
```

- Never commit `local.settings.json` with real secrets. Use environment variables in CI/build pipelines or Key Vault for production.

## Container / App configuration (production)

- Use Azure Key Vault references (recommended) or environment variables set in the platform (Container Apps, App Service, etc.).
- Recommended Key Vault secret naming convention:
  - `secrets/cosmos-conn` — Cosmos DB connection string
  - `secrets/acr-credentials` — if you must store registry creds (avoid if using MI)
  - `secrets/dab-config-json` — optional: DAB config if not baked into image
  - `secrets/jwt-signing-key` — if using app-specific signing keys

## DefaultAzureCredential and Managed Identity notes

- The repository uses `DefaultAzureCredential` in several places (seeder, functions). In Azure this will pick Managed Identity when available. Locally it will fall back to Visual Studio / Azure CLI credentials.
- Recommended workflow:
  1. For infrastructure and prod apps, enable a system- or user-assigned managed identity and grant it minimal permissions (ACR pull, Cosmos DB data contributor where needed).
  2. Grant the seeder or automation identity the appropriate Cosmos DB data-plane role (Cosmos DB Built-in Data Contributor) to allow writes.

## Sample Azure CLI snippets (replace placeholders)

- Set a secret in Key Vault (PowerShell / bash):

```powershell
# Set variables
$kvName = "<your-keyvault-name>"
az keyvault secret set --vault-name $kvName --name "secrets/cosmos-conn" --value "<COSMOS_CONNECTION_STRING>"
```

- Assign AcrPull role to a managed identity for an ACR:

```powershell
$identityPrincipalId = "<managed-identity-principal-id>"
$acrResourceId = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/<acr>"
az role assignment create --assignee $identityPrincipalId --role "AcrPull" --scope $acrResourceId
```

- Grant Cosmos DB data contributor (data-plane) role to a principal (replace scope with your cosmos account resource id):

```powershell
$principalId = "<principal-object-id>"
$cosmosResourceId = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.DocumentDB/databaseAccounts/<cosmosAccount>"
az role assignment create --assignee $principalId --role "Cosmos DB Built-in Data Contributor" --scope $cosmosResourceId
```

## CI / Pipeline recommendations

- Use Key Vault-backed secrets in your pipeline for deployments. Example actions:
  - Fetch Key Vault secrets in pipeline and inject as environment variables to deployment step.
  - Use a service principal scoped to the resource group for CI only if necessary; prefer managed identities in production.

## Troubleshooting

- If apps can't read secrets in Azure: verify Key Vault access policies or RBAC, and that the managed identity is enabled and has GET permission for secrets (or is granted Key Vault Secrets User role via RBAC).
- If DAB/Portal can't pull image: confirm ACR role assignment and that the container host has network access to the registry.

---

## Per-service environment variable mappings

A compact mapping of environment variables used by each service, their purpose, and where to set them.

| Env var | Purpose | Service(s) | Where to set |
|---|---|---|---|
| COSMOS_CONN | Cosmos DB connection string (read-only for queries or read-write for seeder) | DAB, Functions, Seeder | Key Vault secret (`secrets/cosmos-conn`) or platform env |
| DAB_GRAPHQL_URL | GraphQL endpoint for the Data API Builder | Management Portal (frontend/back-end integrations), Tests | Platform env for deployed portal; `local.settings.json` for local dev |
| DAB_CONFIG_FILE / DAB_CONFIG_BLOB | Path or blob name for DAB config JSON (if not baked into image) | DAB (container) | Mount/secret reference or baked into image |
| ASPNETCORE_URLS | Container binding URL (e.g. `http://+:5000`) | DAB | Container env / image Dockerfile |
| ACR_SERVER | ACR login server (for image pulls) | Container hosting infra | Platform env / container registry setting |
| KEY_VAULT_NAME | Name of Key Vault storing secrets | All services that read secrets | Platform env / deployment parameter |
| AzureWebJobsStorage | Functions storage account connection | Azure Functions | Key Vault or platform env |
| FUNCTIONS_WORKER_RUNTIME | Worker runtime for Functions | Azure Functions (local/dev) | `local.settings.json` or platform env |
| APPINSIGHTS_CONNECTION_STRING | Application Insights ingestion | Portal, Functions, DAB (optional) | Key Vault or platform env |
| AZURE_CLIENT_ID / AZURE_TENANT_ID / AZURE_CLIENT_SECRET | Service principal credentials (only for SP-based auth; prefer MI) | Seeder (if not using DefaultAzureCredential) | CI secret or Key Vault (avoid committing) |
| SEEDER_CLIENT_ID / SEEDER_TENANT_ID / SEEDER_CLIENT_SECRET | Optional separate SP used by seeder automation | Seeder | Key Vault / pipeline secret |
| JWT_SIGNING_KEY | App-specific JWT signing secret (if used) | Portal / API | Key Vault secret |

Notes:

- Prefer Managed Identity + DefaultAzureCredential: avoids storing tenant/client secrets. When MI is used, set `KEY_VAULT_NAME` and assign proper access to the identity.
- Use Key Vault references in Container Apps (or App Service managed identity + Key Vault) rather than injecting raw secrets into env vars where the platform supports it.
- For local development, use `local.settings.json` or environment variables on your workstation; never commit secret values.


- **Version**: 1.3.0
- **Last Updated**: 2025-08-18 01:08:00 UTC  
- **Status**: Current
- **Next Review**: 2025-11

---

*Part of the [Azure Stamps Pattern](../README.md) documentation suite*

If you want, I can now add a brief section listing the exact env var names per repository component (file paths) — say "add per-component file mappings" and I'll insert them next.
---

**📝 Document Version Information**
- **Version**: 1.3.0
- **Last Updated**: 2025-08-18 01:28:00 UTC  
- **Status**: Current
- **Next Review**: 2025-11