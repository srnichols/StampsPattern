# Repository Map

Quick map of the repository structure and where common tasks live. Use this when you want to find code, infra, docs, or runbooks quickly.

Top-level folders

- `AzureArchitecture/` — Azure Functions app, Seeder, Bicep modules used by core infra; contains `AzureArchitecture.sln`, function classes, and examples.
- `management-portal/` — Management Portal UI, DAB config, and portal infra (Container Apps bicep). Key files:
  - `management-portal/infra/management-portal.bicep` — IaC for portal and DAB
  - `management-portal/dab/` — DAB Dockerfile, `dab-config.json`, `schema.graphql`
  - `management-portal/src/Portal/` — Blazor UI and GraphQL client wiring
- `docs/` — Documentation hub and guides (this folder). Core docs include `DOCS.md`, `DEPLOYMENT_GUIDE.md`, `KNOWN_ISSUES.md`.
- `scripts/` — Devops and deployment helper scripts (PowerShell and Bash), link-checker, smoke tests, and deploy helpers.
- `infra/` — Optional reference infra and alz-starter templates used for example deployments.
- `config/` — Mapping files and parameter maps (e.g., `azure-region-mapping.json`).
- `docs/one-pagers/` & `docs/releases/` — executive briefs and release notes.

Where to look for common tasks

- Deploy the platform (full): `scripts/deploy-stamps.ps1` + `traffic-routing.bicep`
- Run local Functions & Emulator: `AzureArchitecture/` with `func start` and `./scripts/run-local.ps1`
- Seed baseline data: `AzureArchitecture/Seeder/` — uses `DefaultAzureCredential`
- Fix DAB or Portal: `management-portal/dab/` and `management-portal/src/Portal/`
- CI/Build workflows: `.github/workflows/` (GitHub Actions)

Quick file index

- `README.md` — project overview and minimal happy path
- `docs/DOCS.md` — documentation sitemap and learning paths
- `docs/DOCS.md` — improvement plan and backlog
- `management-portal/infra/management-portal.bicep` — DAB and Portal IaC
- `AzureArchitecture/Seeder/` — seeder project to populate Cosmos

If you can't find a file, use `git grep <term>` or open the `docs/DOCS.md` sitemap.
---

**📝 Document Version Information**
- **Version**: 1.6.3
- **Last Updated**: 2025-09-03 13:23:49 UTC  
- **Status**: Current
- **Next Review**: 2025-11
