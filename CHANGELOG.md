# Changelog

All notable changes to the Azure Stamps Pattern project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.6] - 2025-08-18

### Changed

- Repository organization: moved troubleshooting files to `docs/archive/troubleshooting/`
- Repository organization: moved temporary files to `temp/` directory  
- Repository organization: moved tools to `docs/tools/`
- Repository organization: moved `azuredeploy.json` to `AzureArchitecture/`
- Repository cleanup: removed duplicate `bin/` directory
- Documentation: significant markdown lint improvements (code fence languages, ordered lists, link fragments)

## [1.2.3] - 2025-08-17

### Added

- Complete documentation reorganization and cleanup
- Live Data Path guide for Portal → DAB → Cosmos validation  
- Repaired Documentation Hub with role-based learning paths
- Enhanced Quick Navigation in README with proper links

### Changed

- Normalized Parameterization Guide links to HTML anchors across all documentation
- Improved code fence labeling (mermaid, powershell, jsonc) for better markdown lint compliance
- Tidied Developer Quickstart with clearer Minimal Happy Path section
- Fixed broken relative links in documentation

### Fixed

- Removed duplicate content from LIVE_DATA_PATH.md
- Corrected README Quick Navigation link to point to docs/DOCS.md
- Resolved corrupted Documentation Hub content
- Applied markdownlint autofix across repository where safe

## [1.2.2] - 2025-08-14

### Added

- Fixed authentication redirect loop (AADSTS700054) and enabled ID token issuance for Stamps Portal

## [1.2.1] - 2025-08-14

### Added

- Enhanced version management system with automated documentation footer updates
- Restored DEPLOYMENT_ARCHITECTURE_GUIDE.md with critical subscription deployment patterns
- Comprehensive documentation link validation and cleanup

### Changed

- Improved version script to update multiple documentation files with version footers
- Fixed README.md formatting and badge consistency
- Updated all documentation cross-references to use active files instead of archived ones

### Fixed

- Documentation link integrity across all guides
- Version badge and header formatting in README.md
- Archive organization with proper historical context

## [1.2.0] - 2025-08-14

### Added

- **Management Portal Authentication**: Complete Azure Entra ID integration with OpenID Connect
  - Container Apps deployment with authentication middleware
  - Support for Azure AD app registrations and role-based access control
  - Production-ready authentication configuration with HTTPS redirect handling
- **Container Apps Infrastructure**: Production deployment of management portal and DAB services
  - Auto-scaling configuration (1-5 replicas for portal, 1-3 for DAB)
  - Container Registry integration with custom images
  - Managed identity configuration for secure service-to-service communication
- **Enhanced Monitoring**: Application Insights integration with custom dashboards
  - Error rate and response time alerting
  - Container Apps performance monitoring
  - Authentication flow tracking and troubleshooting

### Changed

- **Documentation Updates**: Enhanced deployment and user guides with authentication setup
  - Updated DEPLOYMENT_GUIDE.md with management portal authentication requirements
  - Improved MANAGEMENT_PORTAL_USER_GUIDE.md with authentication flow details
  - Enhanced management-portal README with production authentication guidelines
- **Security Improvements**: HTTPS enforcement and forwarded headers handling for container environments

### Fixed

- **HTTPS Redirect Issues**: Resolved authentication redirect URI problems in container environments
- **Azure AD Token Configuration**: Fixed AADSTS700054 errors with proper ID token enablement
- **Container App Secrets**: Proper client secret configuration and management

### Archived

- Moved temporary authentication setup documentation to docs/archive/
  - FINAL_AUTH_SETUP.md
  - AZURE_ENTRA_SETUP.md  
  - FIX_AADSTS700054.md
  - MANUAL_AUTH_FIX.md
  - DEPLOYMENT_ARCHITECTURE_GUIDE.md
  - MONITORING_GUIDE.md

## [1.1.0] - Previous Release

- Base Azure Stamps Pattern infrastructure
- Bicep templates for multi-tenant architecture
- Azure Functions for tenant management
- Cosmos DB integration for control plane data

## [1.0.0] - Initial Release

- Azure Stamps Pattern foundation
- Multi-tenant architecture patterns
- Security and compliance frameworks
- Documentation and deployment guides
