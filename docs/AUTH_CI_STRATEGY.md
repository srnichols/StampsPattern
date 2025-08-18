# Auth & CI Strategy (quick reference)

Purpose

Scope

Key patterns

1) Portal authentication (AAD)

2) DAB and secrets

3) Seeder authentication

Common AAD errors & quick fixes


CI recommendations (minimal)


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


```powershell
az deployment group create -g rg-stamps-mgmt -f management-portal/infra/management-portal.bicep --parameters @management-portal/infra/parameters.json
```

Secrets guidance (quick)

Minimal RBAC (starter)

Related docs
# Azure CI/CD & Authentication Strategy

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
