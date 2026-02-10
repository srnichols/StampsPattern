# Git Workflow — Instructions

applyTo: ".github/workflows/**/*.yml,CONTRIBUTING.md"

## Branching Strategy

- **Default branch**: `main`
- **Branch naming**: `feat/<scope>`, `fix/<scope>`, `docs/<scope>`, `chore/<scope>`, `refactor/<scope>`, `test/<scope>`
- Create feature branches from `main`
- Keep changes focused and incremental — prefer multiple small PRs over one large PR

## Commit Conventions

Use **Conventional Commits**:

```
feat: add tenant migration validation logic
fix: correct CELL capacity calculation for shared CELLs
docs: update deployment guide with SQL SKU parameters
chore: update Bicep CLI version in CI workflow
refactor: extract CELL assignment into service class
test: add unit tests for compliance matching
```

## Pull Request Checklist

- [ ] Clear description of the change and rationale
- [ ] Scope is focused; unrelated changes split out
- [ ] Added/updated docs where needed
- [ ] Added/updated tests (if applicable)
- [ ] No broken links or anchors in docs
- [ ] Follows commit and branch conventions
- [ ] CI passes (build, lint, basic checks)

For docs PRs, run the link checker locally before opening:

```powershell
pwsh -File ./scripts/verify-doc-links.ps1 -IncludeImages
```

## CI/CD Workflows

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| CI/CD | `ci-cd.yml` | `workflow_dispatch` | Full build, test, Bicep validate, deploy |
| Validate | `validate.yml` | `workflow_dispatch` | Bicep compilation and best practices |
| Bicep Lint | `bicep-lint.yml` | PR/Push | Bicep linting rules |
| Bicep What-If | `bicep-whatif.yml` | PR | Preview infrastructure changes |
| Markdown Lint | `markdownlint.yml` | PR | Markdown style enforcement |
| Link Check | `docs-link-check.yml` | PR | Doc link verification |
| Deploy Portal | `deploy-management-portal.yml` | `workflow_dispatch` | Portal to Container Apps |
| Deploy Infra | `deploy.yml` | `workflow_dispatch` | Infrastructure deployment |

> **Note**: Most workflows are currently set to `workflow_dispatch` (manual) for single-developer iteration speed. Restore push/PR triggers for team workflows.

## CI Pipeline Steps (ci-cd.yml)

1. **Bicep Validation**: Build all `.bicep` files, run what-if deployment
2. **.NET Build**: Restore → Build (Release config) → Test
3. **Package**: Publish Functions app
4. **Deploy**: Deploy to Azure (requires `AZURE_CREDENTIALS` secret)

## Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `AZURE_CREDENTIALS` | Service principal credentials (JSON) |
| `SQL_ADMIN_PASSWORD` | SQL admin password for what-if/deploy |

## Code Review Guidelines

- Architecture changes require explanation in PR description
- Bicep changes should include what-if output
- Security-sensitive changes require explicit review
- Documentation changes: verify all links resolve correctly

## Issue Reporting

- Use GitHub Issues with appropriate labels: `bug`, `enhancement`, `question`
- Include: expected vs actual behavior, repro steps, environment, logs/screenshots
- Security issues: **never** open a public issue — use private disclosure channels
