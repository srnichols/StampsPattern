# Temporary Files Directory

This directory contains temporary configuration files and JSON artifacts from development and testing.

## Contents

- `ca-stamps-portal-*.json`: Container App configuration backups and patches
- `app-update.json`, `azure-credentials.json`: Authentication configuration files  
- `federated-credential.json`: OIDC configuration artifacts
- `dab.json`, `portal.json`: Data API Builder and Portal configurations
- `temp-app-config.json`: Temporary application configuration

## Purpose

These files are temporary artifacts from development, testing, and troubleshooting. They may contain sensitive configuration data or environment-specific settings.

## Security Note

⚠️ **These files may contain sensitive information**. Review contents before sharing or committing to source control.

## Cleanup

These files can typically be safely deleted once deployments are stable and configurations are properly managed through the main infrastructure templates.
