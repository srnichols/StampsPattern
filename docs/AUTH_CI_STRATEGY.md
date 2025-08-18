````markdown
# Auth & CI Strategy (quick reference)

Purpose
- Consolidate authentication patterns (Portal, DAB, Seeder) and CI recommendations for first-time readers and operators.

Scope
- Portal sign-in: Microsoft Entra / AAD (id_token)
- Portal -> DAB: internal network calls using container-app secrets; DAB uses MI or connection string to talk to Cosmos
- Seeder: uses DefaultAzureCredential (local dev) or a service principal/managed identity in CI
- CI: GitHub Actions example for pushing DAB image to ACR and running IaC non-interactively

Key patterns

1) Portal authentication (AAD)
- Use an AAD app registration for the Management Portal (SPA/Server components). Configure redirect URIs and implicit flow or code flow with PKCE for SPA.

2) DAB and secrets
- DAB does not require user interactive auth. For production, prefer a Managed Identity attached to the Container App with RBAC roles (Cosmos DB Data Reader/Contributor as required).
- Optionally store `DAB_GRAPHQL_URL` and other secrets in Key Vault and use container-app identity to access them; or use container-app secretRefs for simpler setups.

3) Seeder authentication
- Local developer: `DefaultAzureCredential` will use Visual Studio / Azure CLI cached creds. Ensure the signed-in account has Data Contributor on the Cosmos account.
- CI: create a service principal or GitHub federated credential with minimal RBAC scope (Cosmos data contributor on `stamps-control-plane`).

Common AAD errors & quick fixes

- AADSTS700016: Application with identifier 'xyz' not found — check App Registration clientId and tenant.
- AADSTS50011: Redirect URI mismatch — register exact URI (including trailing slash) used by the portal.
- 401/403 on seeder: role missing — assign Cosmos DB Built-in Data Contributor to the cred principal.

CI recommendations (minimal)

- Build & push DAB image to ACR (use GitHub Actions with OIDC federated identity or service principal):

```yaml
# Example job snippet (GitHub Actions)
jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions: write-all
    steps:
      - uses: actions/checkout@v4
      - name: Login to ACR (OIDC)
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - name: Build and push
        run: |
          docker build -t $ACR/my-dab:latest ./management-portal/dab
          docker push $ACR/my-dab:latest
```

- Non-interactive IaC deploy example (PowerShell):

```powershell
az deployment group create -g rg-stamps-mgmt -f management-portal/infra/management-portal.bicep --parameters @management-portal/infra/parameters.json
```

Secrets guidance (quick)
- For P0, container-app secrets are quickest. For production, prefer Key Vault with managed identity to avoid secret leakage in repos.

Minimal RBAC (starter)
- Managed Identity for container apps: AcrPull role on ACR and Cosmos DB Data Contributor on the database.
- Seeder/CI identity: Cosmos DB Data Contributor on `stamps-control-plane` and limited scope service principal for ACR push (ACR Push role).

Related docs
- `docs/LIVE_DATA_PATH.md` — quick smoke checks and GraphQL examples
- `management-portal/infra/management-portal.bicep` — parameter names and secret wiring
````
# Auth & CI Strategy (summary)

Purpose: consolidate authentication and CI notes for implementers and reviewers.

1) Authentication summary
- Portal: Azure AD / Microsoft Entra External ID for admin sign-in (OIDC, id_token)
- Data-plane: DAB uses managed identity or a Cosmos connection string; prefer managed identity + RBAC
- Seeder: use DefaultAzureCredential (AZ CLI logged-in user or service principal in CI)

2) App registration checklist (Portal)
- Platform: Web
- Redirect URI: https://{portal-url}/signin-oidc
- Logout URI: https://{portal-url}/signout-callback-oidc
- Enable ID tokens
- Add app roles (platform.admin, operator, reader)

3) CI recommendations (GitHub Actions)
- Use OIDC federated credentials for least privilege (avoid long-lived secrets)
- Required secrets: minimal (only for operations that can't use OIDC)
- Typical flow: OIDC -> short-lived role assignment -> az deployment group create

4) Common AAD errors and remediation
- AADSTS50011 (redirect mismatch): update authorized redirect URIs in app registration
- AADSTS700016 (app not found): ensure app registration exists in correct tenant and client id used
- 401/403 on data-plane: check role assignment scope and type (Data Contributor vs Owner)

5) Quick commands
- Create federated credential (example, replace placeholders):
  ```powershell
  az ad app federated-credential create --id <appId> --parameters '{"name":"gh-actions","issuer":"https://token.actions.githubusercontent.com","subject":"repo:owner/repo:ref:refs/heads/main","audiences":["api://AzureADTokenExchange"]}'
  ```

6) Next steps
- Expand this page with common error codes, example OIDC setups, and a sample GitHub Actions deploy job using OIDC. Link back to `docs/SECURITY_GUIDE.md` and deployment docs.
