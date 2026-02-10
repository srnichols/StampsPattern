# Deployment & DevOps — Instructions

applyTo: "scripts/**/*.ps1,scripts/**/*.sh,.github/workflows/**/*.yml,azure.yaml"

## Local Development

### Prerequisites
- .NET 6 SDK
- Azure Functions Core Tools v4 (`func`)
- Azurite (local Azure Storage emulator)
- Azure Cosmos DB Emulator (or live Cosmos DB instance)
- Azure CLI with Bicep CLI installed
- PowerShell 7+

### Running Locally
1. Copy `local.settings.template.json` → `local.settings.json` and fill in values
2. Start Azurite: `azurite --silent --location AzureArchitecture/.azurite`
3. Build: `dotnet build` from `AzureArchitecture/`
4. Run: `func start` from `AzureArchitecture/`
5. Or use VS Code tasks: "Run: Dev Stack" starts both Azurite and Functions

### VS Code Tasks (defined in `.vscode/tasks.json`)
- **Build: Functions** — `dotnet build` in AzureArchitecture
- **Run: Functions (local)** — `func start` (depends on build)
- **Run: Azurite (local)** — Starts Azurite storage emulator
- **Run: Dev Stack** — Starts both Azurite and Functions together

## Secrets Management

- **Never** commit secrets to source control
- `local.settings.json` is in `.gitignore` — use it only for local dev
- Production secrets go in **Azure Key Vault**
- Key Vault secret naming: `secrets/cosmos-conn`, `secrets/acr-credentials`, `secrets/graphql-config`
- Use `DefaultAzureCredential` everywhere — it picks Managed Identity in Azure, CLI/VS creds locally
- Env vars for auth: `EXTERNAL_ID_TENANT`, `EXTERNAL_ID_CLIENT_ID`, `B2C_TENANT`, `B2C_CLIENT_ID`

## Azure Deployment

### Bicep Deployment
```powershell
# Create resource group
az group create --name rg-stamps-{scope}-{env} --location eastus

# Deploy main template
az deployment sub create \
  --location eastus \
  --template-file AzureArchitecture/main.bicep \
  --parameters @AzureArchitecture/main.parameters.json \
  --parameters sqlAdminPassword="<secure-password>"
```

### What-If Preview
```powershell
az deployment sub what-if \
  --location eastus \
  --template-file AzureArchitecture/main.bicep \
  --parameters @AzureArchitecture/main.parameters.json
```

### Management Portal (azd)
```powershell
azd up  # From repo root — deploys Portal to Container Apps
```

### Key Scripts
| Script | Purpose |
|--------|---------|
| `scripts/deploy.ps1` | Full infrastructure deployment |
| `scripts/deploy-stamps.ps1` | Deploy stamp/CELL layer |
| `scripts/deploy-global-layer.ps1` | Deploy global layer only |
| `scripts/deploy-routing.ps1` | Configure traffic routing |
| `scripts/deploy-frontdoor-only.ps1` | Front Door standalone deployment |
| `scripts/what-if.ps1` | Deployment what-if preview |
| `scripts/smoke-functions.ps1` | Smoke test Functions endpoints |
| `scripts/diagnostics.ps1` | Infrastructure diagnostics |
| `scripts/run-local.ps1` | Start local dev environment |
| `scripts/stop-local.ps1` | Stop local dev environment |

## CI/CD Workflows

Located in `.github/workflows/`:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci-cd.yml` | Manual (dispatch) | Full build, test, Bicep validation, deployment |
| `validate.yml` | Manual (dispatch) | Bicep template validation and best practices |
| `bicep-lint.yml` | PR/push | Bicep linting |
| `bicep-whatif.yml` | PR | Bicep what-if deployment preview |
| `markdownlint.yml` | PR | Markdown linting |
| `docs-link-check.yml` | PR | Documentation link verification |
| `deploy-management-portal.yml` | Manual | Portal deployment to Container Apps |

Note: CI/CD triggers are currently set to `workflow_dispatch` (manual) while iterating as a single developer. Restore push/PR triggers for team workflows.

## Deployment Environments

- `dev` — Development/iteration, minimal Defender, Developer SKU APIM
- `test` — Integration testing (default), same cost profile as dev
- `staging` — Pre-production validation
- `prod` — Full production: Premium APIM, zone-redundant Cosmos, paid Defender plans

## PowerShell Script Conventions

- Use `pwsh` (PowerShell 7+) — not Windows PowerShell 5.1
- Include `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`
- Use verbose parameter names (not aliases) in scripts
- Validate required parameters at script entry
- Use Azure CLI (`az`) for Azure operations, not AzPowerShell where possible for portability
