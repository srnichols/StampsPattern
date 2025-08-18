# RBAC Cheat Sheet

Purpose
- Quick role assignments and example commands for identities used in the Stamps Pattern.

Common roles and why

- `AcrPull` — allow managed identities or service principals to pull images from ACR.
- `Cosmos DB Built-in Data Contributor` — data-plane role to allow SDK operations against containers.
- `Contributor` / `Owner` — infra-level roles (use sparingly).
- `Key Vault Secrets User` / `Key Vault Administrator` — to access or manage Key Vault secrets.

Example: assign AcrPull to a managed identity

```powershell
# Assign AcrPull to user-assigned managed identity
ACR_RESOURCE_ID=$(az acr show -n crxgjwtecm3g5pi -g rg-stamps-mgmt --query id -o tsv)
MI_PRINCIPAL_ID=$(az identity show -n mi-stamps-mgmt -g rg-stamps-mgmt --query principalId -o tsv)
az role assignment create --assignee $MI_PRINCIPAL_ID --role "AcrPull" --scope $ACR_RESOURCE_ID
```

Example: grant Cosmos DB data contributor to a principal (data-plane)

```powershell
COSMOS_RESOURCE_ID=$(az cosmosdb show -n cosmos-xgjwtecm3g5pi -g rg-stamps-mgmt --query id -o tsv)
PRINCIPAL_ID=$(az ad user show --id you@yourdomain.com --query objectId -o tsv)
az role assignment create --assignee $PRINCIPAL_ID --role "Cosmos DB Built-in Data Contributor" --scope $COSMOS_RESOURCE_ID
```

Notes
- Prefer granting data-plane roles scoped to the Cosmos account rather than subscription-wide.
- For CI, prefer GitHub OIDC federation to avoid long-lived secrets. Assign minimal roles to the federated principal.
- When debugging 401/403 from the seeder, confirm identity used by `DefaultAzureCredential` matches the principal you granted the role to (CLI user vs VS user vs SP).

Related docs
- `docs/SECRETS_AND_CONFIG.md` — how secrets & Key Vault tie into RBAC
- `docs/AUTH_CI_STRATEGY.md` — CI & identity patterns

