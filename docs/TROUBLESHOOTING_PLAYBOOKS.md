# 🔧 Troubleshooting Playbooks (P2)

Concise, operator-focused playbooks that expand the decision trees into step-by-step commands you can run during incidents. All commands are PowerShell-friendly and use `az` where applicable. Replace placeholders (resource names, principal IDs, image tags) with your environment values.

> Quick tip: run these commands from a machine with Azure CLI logged in and the contributor role for the target subscription.

---

## 1) Portal → DAB connectivity (playbook)

Goal: confirm the portal can reach DAB GraphQL and diagnose where the failure sits (config, DNS, network, auth, or DAB itself).

Checklist:
- [ ] Confirm portal `DAB_GRAPHQL_URL` secret is correct
- [ ] Confirm DAB Container App revision is healthy
- [ ] Tail DAB logs for GraphQL errors
- [ ] Run an introspection query against DAB

Step-by-step

1) Inspect portal configuration (secret env var)

```powershell
# Show env used by the portal container (replace RG and name)
az containerapp show --name ca-stamps-portal --resource-group rg-stamps-mgmt --query "properties.template.containers[0].env" -o table

# If using secrets, list them (names only)
az containerapp secret list --name ca-stamps-portal --resource-group rg-stamps-mgmt -o table
```

2) Check the `DAB_GRAPHQL_URL` value and try a raw HTTP POST from your workstation

```powershell
$dab = 'https://<dab-ingress-fqdn>/graphql'
$body = '{"query":"{ __schema { types { name } } }"}'

# Simple POST (PowerShell Invoke-RestMethod):
Invoke-RestMethod -Method POST -Uri $dab -Body $body -ContentType 'application/json' -ErrorAction Stop

# If Portal uses Key Vault/managed identity to fetch the URL, ensure Portal can read the secret (see AAD section below)
```

3) Inspect Container App and revision status for DAB

```powershell
az containerapp revision list -g rg-stamps-mgmt -n ca-stamps-dab -o table
az containerapp show -g rg-stamps-mgmt -n ca-stamps-dab --query properties.configuration.ingress -o json

# Tail logs (container name in the DAB image is usually 'dab')
az containerapp logs show -g rg-stamps-mgmt -n ca-stamps-dab --container dab --tail 300
```

4) If you get 401/403 from the portal when it calls DAB

```powershell
# Check Portal principal/secret access: ensure portal has KeyVault Get or the secret is present as a Container App secret
az keyvault secret show --vault-name <kv-name> --name DAB_GRAPHQL_URL

# If Portal relies on managed identity to fetch an endpoint, ensure the identity is assigned and has appropriate Key Vault or role assignments
az containerapp show --name ca-stamps-portal -g rg-stamps-mgmt --query properties.identity
```

5) If DAB responds but GraphQL errors appear, run an introspection or specific query to see schema/status

```powershell
Invoke-RestMethod -Method POST -Uri $dab -Body '{"query":"{ __schema { queryType { name } } }"}' -ContentType 'application/json'
```

If the above shows schema, the portal should be able to fetch data; if not, continue with the DAB startup playbook below.

---

## 2) DAB container startup (playbook)

Goal: diagnose container start failures, image pull problems, missing config files, or permission errors.

Checklist:
- [ ] Confirm image exists in ACR
- [ ] Confirm managed identity has AcrPull on ACR
- [ ] Tail container logs for startup exceptions
- [ ] Confirm /App/dab-config.json is present or mapped

Step-by-step

1) Check container app revision state and recent events

```powershell
az containerapp revision list --name ca-stamps-dab --resource-group rg-stamps-mgmt --output table
az containerapp show --name ca-stamps-dab --resource-group rg-stamps-mgmt --query properties.template.containers -o json
```

2) If the revision failed to pull the image, validate ACR and managed identity

```powershell
# Check image exists
az acr repository show --name <acrName> --repository <repo> --output table

# Get ACR resource id
$acrId = az acr show --name <acrName> --resource-group <acrRg> --query id -o tsv

# Assign AcrPull to managed identity (use principalId from container app identity)
az role assignment create --assignee <principalId-or-objectId> --role AcrPull --scope $acrId

# After assigning role, restart the containerapp revision or create a new revision
az containerapp revision restart --name ca-stamps-dab --resource-group rg-stamps-mgmt
```

3) Tail logs and inspect startup stacktraces

```powershell
az containerapp logs show -g rg-stamps-mgmt -n ca-stamps-dab --container dab --tail 500

# If logs show missing file errors, confirm the image contains /App/dab-config.json or that the containerapp mounts it via secret
az containerapp show --name ca-stamps-dab --resource-group rg-stamps-mgmt --query properties.template.containers[0].env -o table
```

4) If config is missing, either rebuild the image to include the file or inject config via secret/file mount

```powershell
# Example: store dab-config.json as a secret (if small) and set env to secretref
az containerapp secret set --name ca-stamps-dab --resource-group rg-stamps-mgmt --secrets dab-config='{"key":"value"}'

# Update container app environment variables to reference secretref if code supports it
az containerapp update --name ca-stamps-dab --resource-group rg-stamps-mgmt --set properties.template.containers[0].env[?name=='DAB_CONFIG'].value='secretref:dab-config'
```

5) If the container starts but GraphQL endpoints return 500s, inspect logs for unhandled exceptions and missing connection strings (Cosmos/KeyVault)

```powershell
# Check environment variables for missing values
az containerapp show --name ca-stamps-dab --resource-group rg-stamps-mgmt --query properties.template.containers[0].env -o table

# Verify Cosmos DB connection string or use managed identity; if using system/user assigned MI, check role assignment
az role assignment list --assignee <principalId> --scope $(az cosmosdb show --name <cosmosName> --resource-group <rg> --query id -o tsv)
```

If you must rebuild the image, follow normal build/push flow and update the containerapp image to the new tag, then monitor logs.

---

## 3) AAD / Authentication (playbook)

Goal: fix 401/403 issues coming from local dev or deployed services using DefaultAzureCredential or managed identities.

Checklist:
- [ ] Determine if call is from local dev or deployed resource
- [ ] For local dev: verify `az login` or VS Code account
- [ ] For deployed: confirm managed identity presence and role assignments

Step-by-step

1) Local dev troubleshooting

```powershell
# Verify CLI login
az account show

# Test token for resource (KeyVault/ACR/Cosmos)
az account get-access-token --resource https://vault.azure.net

# If using Visual Studio/VS Code credentials, ensure extension is signed in
```

2) Deployed resource troubleshooting (managed identity)

```powershell
# Show container app identity
az containerapp show --name ca-stamps-dab --resource-group rg-stamps-mgmt --query properties.identity -o json

# If user-assigned, get principalId and verify role assignments
az role assignment list --assignee <principalId> --scope $(az cosmosdb show --name <cosmosName> --resource-group <rg> --query id -o tsv)

# Grant Cosmos DB Data Contributor role if missing (data plane role)
az role assignment create --assignee <principalId> --role "Cosmos DB Built-in Data Contributor" --scope $(az cosmosdb show --name <cosmosName> --resource-group <rg> --query id -o tsv)

# Grant AcrPull role for ACR pulls
az role assignment create --assignee <principalId> --role AcrPull --scope $(az acr show --name <acrName> --resource-group <acrRg> --query id -o tsv)

# Grant Key Vault access policy (if using access policies rather than role-based access)
az keyvault set-policy --name <kvName> --object-id <principalId> --secret-permissions get list
```

3) If token audience/scopes appear incorrect

```powershell
# Capture a token and inspect it on jwt.ms or decode locally
$tok = az account get-access-token --resource https://management.azure.com
Write-Output $tok.accessToken.Substring(0,200) # do not paste full tokens in public logs

# Use jwt.ms to inspect aud/roles/scopes
```

4) Wait for role propagation and retry (role assignments can take 1-5 minutes)

---

Appendix: useful quick commands

```powershell
# Container app logs (generic)
az containerapp logs show --name <name> --resource-group <rg> --tail 300

# Container app show
az containerapp show --name <name> --resource-group <rg>

# Restart container app revision
az containerapp revision restart --name <name> --resource-group <rg>

# List role assignments for a principal
az role assignment list --assignee <principalId>

# Inspect ACR repository
az acr repository show --name <acrName> --repository <repo>

# Assign role
az role assignment create --assignee <principalId> --role AcrPull --scope <scope>
```

---

If you'd like, I can also:
- convert these playbooks into step-by-step runbooks in `docs/OPERATIONS_GUIDE.md` under a dedicated "Incident Playbooks" section, or
- add a small `bin/diagnostics.ps1` script that runs a subset of these checks and prints a short report for the current environment.
