# Examples: Quick-start parameter files

This folder contains sample parameter sets for `AzureArchitecture/main.bicep`.

- `main.sample.smoke.json`, minimal, lab-friendly. Sets `useHttpForSmoke: true` to avoid Key Vault certs; good for what-if and first deploys.
- `main.sample.silver.json`, moderate HA; still lab-friendly.
- `main.sample.platinum.json`, higher HA/DR toggles; still lab-friendly.

Notes:
- `additionalLocations` is an array of region name strings (e.g., ["westus2", "westeurope"]). Failover priority is computed internally by the template.
- The template auto-creates per-region networking (VNet, `subnet-agw`, Public IP) for initial runs.
- For production HTTPS, set `useHttpForSmoke` to false and ensure the Key Vault certificate references in the template are valid.

Profiles and diagnostics:
- `environmentProfile` drives defaults: `smoke` (minimal), `dev` (default), `prod` (full features).
- Smoke mode is derived as `isSmoke = useHttpForSmoke || environmentProfile == 'smoke'`.
- Diagnostics: the stamp layer uses `metricsOnly` in smoke and `standard` in dev/prod; you can override per-cell if needed.

Typical usage (PowerShell):

```powershell
$rg = "rg-stamps-smoke"
$tmpl = "e:/GitHub/StampsPattern/AzureArchitecture/main.bicep"
$params = "e:/GitHub/StampsPattern/AzureArchitecture/examples/main.sample.smoke.json"

az group create --name $rg --location eastus
az deployment group what-if --resource-group $rg --template-file $tmpl --parameters @$params
az deployment group create --resource-group $rg --template-file $tmpl --parameters @$params --verbose
```

Or use the helper to run What-If by profile (smoke/dev/prod):

```powershell
./scripts/what-if.ps1 -Profile smoke -ResourceGroup rg-stamps-smoke -Location eastus
```

To deploy by profile (smoke/dev/prod):

```powershell
./scripts/deploy.ps1 -Profile smoke -ResourceGroup rg-stamps-smoke -Location eastus
```
