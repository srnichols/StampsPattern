# Azure Developer CLI (azd) — Instructions

applyTo: "azure.yaml,management-portal/infra/**/*.bicep,management-portal/deploy-*.ps1"

## Overview

The **Azure Developer CLI (`azd`)** is used to deploy the Management Portal to Azure Container Apps. Configuration lives in `azure.yaml` at the repository root.

### Project Configuration

```yaml
# azure.yaml
name: stamps-management-portal
metadata:
  template: stamps-management-portal@0.0.1-beta

services:
  portal:
    project: ./management-portal/src/Portal
    language: dotnet
    host: containerapp
    docker:
      path: ./Dockerfile
      context: .

infra:
  path: ./management-portal/infra
  parameters:
    portalImage: "${AZURE_CONTAINER_REGISTRY_ENDPOINT}/stamps-portal:latest"
```

### Key Commands

| Command | Purpose |
|---------|---------|
| `azd up` | Provision infra + build + deploy (full pipeline) |
| `azd provision` | Create/update Azure resources only |
| `azd deploy` | Build and deploy application only |
| `azd down` | Tear down all provisioned resources |
| `azd env list` | List configured environments |
| `azd env set <key> <value>` | Set environment variable |

### Deployment Workflow

```powershell
# 1. Initialize (first time)
azd init

# 2. Full deploy (provision + build + deploy)
azd up

# 3. Subsequent deploys (code changes only)
azd deploy
```

### Infrastructure

- Bicep templates in `management-portal/infra/`
- Resources provisioned: Container Apps Environment, Container App, ACR, managed identity
- Portal image built and pushed to Azure Container Registry
- Environment variables injected from azd environment

### Post-Deploy Hooks

After successful deployment, `azure.yaml` runs a hook that:
1. Displays the Portal URL
2. Reminds about Entra ID auth configuration
3. Suggests monitoring alert setup
4. Notes custom domain configuration (optional)

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `AZURE_CONTAINER_REGISTRY_ENDPOINT` | ACR login server URL |
| `AZURE_PORTAL_URL` | Deployed portal URL |
| `AZURE_ENV_NAME` | azd environment name |
| `AZURE_LOCATION` | Azure region |
| `AZURE_SUBSCRIPTION_ID` | Target subscription |

### Best Practices

- Use `azd env` to manage environment-specific configuration
- Never hardcode subscription IDs or resource names in `azure.yaml`
- Use `${VAR}` syntax for environment variable substitution in azure.yaml
- Run `azd provision` separately to preview infrastructure changes
- The Aspire-style `global.json` includes `Aspire.Hosting.AppHost.Sdk` for local orchestration
