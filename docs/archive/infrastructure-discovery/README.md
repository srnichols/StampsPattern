# Infrastructure Discovery - Archived Documentation

## Overview

This folder contains documentation for an **Infrastructure Discovery System** that is separate from the current Management Portal implementation.

## Architecture Differences

| Infrastructure Discovery (Archived) | Current Management Portal |
|-------------------------------------|---------------------------|
| **Azure Function** for discovery | **Blazor Server** application |
| **React/Next.js** frontend | **Blazor Server** frontend |
| **Live Azure ARM API** scanning | **Cosmos DB** static data via DAB |
| **Dynamic infrastructure discovery** | **Static data management** |
| **Pattern-based resource group detection** | **Direct database operations** |

## Purpose

The Infrastructure Discovery system was designed to:
- Automatically scan Azure subscriptions for existing stamp deployments
- Use pattern matching to identify stamp resource groups
- Provide real-time discovery of infrastructure changes
- Generate capacity and health analytics

## Current Status

These guides describe a **complementary system** that could work alongside the current Management Portal by:
- Discovering existing stamp infrastructure automatically
- Feeding discovered data into the Management Portal's Cosmos DB
- Providing infrastructure monitoring capabilities

## Files

- [`INFRASTRUCTURE_DISCOVERY_GUIDE.md`](INFRASTRUCTURE_DISCOVERY_GUIDE.md) - Core Azure Function documentation
- [`INFRASTRUCTURE_DISCOVERY_PORTAL_INTEGRATION.md`](INFRASTRUCTURE_DISCOVERY_PORTAL_INTEGRATION.md) - React/Next.js portal integration
- [`INFRASTRUCTURE_DISCOVERY_PRODUCTION_GUIDE.md`](INFRASTRUCTURE_DISCOVERY_PRODUCTION_GUIDE.md) - Production deployment guide
- [`INFRASTRUCTURE_DISCOVERY_TESTING_GUIDE.md`](INFRASTRUCTURE_DISCOVERY_TESTING_GUIDE.md) - Testing strategies

## Related

For the current Management Portal documentation, see the main [`docs/`](../../) folder.