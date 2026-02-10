# Versioning — Instructions

applyTo: "CHANGELOG.md,AzureArchitecture/AzureArchitecture.csproj,azure.yaml"

## Versioning Scheme

This project follows **Semantic Versioning** (`MAJOR.MINOR.PATCH`):

- **MAJOR**: Breaking changes to APIs, Bicep parameter contracts, or tenant data model
- **MINOR**: New features, new Bicep modules, new API endpoints, new tenant capabilities
- **PATCH**: Bug fixes, documentation updates, linting fixes, parameter tweaks

Current version track: `1.6.x` (see CHANGELOG.md)

## Changelog

The `CHANGELOG.md` follows the **Keep a Changelog** format:

```markdown
## [1.6.4] - 2025-09-08

### Added
- Description of new features

### Changed
- Description of changes to existing functionality

### Fixed
- Description of bug fixes

### Removed
- Description of removed features
```

### Changelog Categories

| Category | Use For |
|----------|---------|
| `Added` | New features, new Bicep modules, new API endpoints, new scripts |
| `Changed` | Behavior changes, parameter defaults, SKU changes, doc updates |
| `Fixed` | Bug fixes, linter warnings, deployment script issues |
| `Removed` | Deprecated features, removed parameters, cleaned-up code |
| `Security` | Security patches, vulnerability fixes, auth changes |

### Changelog Conventions

- Every release entry starts with version number and date: `## [x.y.z] - YYYY-MM-DD`
- Group changes by category (Added, Changed, Fixed)
- Keep entries concise but descriptive
- Reference related docs or guides when relevant
- Include documentation footer refresh when version bumps

## Release Process

1. Update version in relevant files (csproj, azure.yaml metadata)
2. Add changelog entry with date
3. Update documentation footers across guides (`scripts/update-doc-footers.ps1`)
4. Tag release: `git tag v1.6.x`
5. Push tag: `git push origin v1.6.x`

## Document Footer Versioning

Documentation files include version and release metadata in footers. Use the provided script to batch-update:

```powershell
pwsh -File ./scripts/update-doc-footers.ps1
```

## Template Metadata

The `azure.yaml` includes template version metadata:

```yaml
metadata:
  template: stamps-management-portal@0.0.1-beta
```

Update this version when the deployment template structure changes.

## Function App Version

The health endpoint reports the application version:

```json
{
  "version": "1.0.0-enterprise",
  "status": "Healthy"
}
```

Update the version string in `DocumentationFunction.cs` when releasing.
