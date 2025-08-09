# Sample Application Plan for Azure Stamp Pattern Infrastructure Framework

## 1. Introduction

This document outlines a detailed plan for developing and integrating a sample application into the Azure Stamp Pattern infrastructure framework. The sample app will serve as a demonstration tool to showcase the functionality of the framework across all types of CELLs (e.g., compute, storage, networking, and hybrid CELLs, assuming standard Stamp Pattern configurations). It will represent demo customer/tenant instances, highlighting multi-tenancy features such as unique URLs, subdomains, routing, and client branding.

The application will be a simple user task tracking app, designed with minimal functionality to prove the concept without unnecessary complexity. No code will be built at this stage; this plan serves as a reference for future implementation.

Key principles guiding this plan:
- **Modularity**: Ensure the app is containerized for easy deployment and scalability.
- **Multi-Tenancy**: Support isolation per tenant while demonstrating shared infrastructure benefits.
- **Technology Stack Alignment**: Adhere to specified technologies for consistency with Azure ecosystem.
- **Deployment Automation**: Leverage Azure Dev CLI (azd) for streamlined deployment from the management portal.

## 2. Objectives

The primary goals of this sample application are:
- Demonstrate a fully functional app deployed across all CELL types in the Stamp Pattern.
- Validate tenant isolation, routing, and branding in a multi-tenant environment.
- Provide a reference implementation for onboarding real customer apps.
- Showcase integration with Azure services for data storage, access, and analytics.
- Ensure the app is simple, maintainable, and extensible for future enhancements.

Success Metrics:
- Successful deployment of tenant instances via the management portal.
- Correct routing to tenant-specific URLs/subdomains.
- Display of tenant branding (e.g., name/business identity in the app header).
- Basic functionality (task creation, viewing, and analytics) working end-to-end.
- Compatibility with Docker Desktop for local testing and Azure Container Apps for production.

## 3. High-Level Architecture Overview

The sample app will follow a microservices-inspired architecture, containerized for deployment into CELLs. It will consist of a frontend, backend/data access layer, and supporting services. The app will be deployed as a single container app bundle, with dependencies on Azure-managed services.

### Architecture Diagram (Conceptual)
(Note: In future documentation, include a visual diagram using tools like Draw.io or Azure Architecture Icons.)

- **Frontend**: .NET 9 Blazor app with Bootstrap 5 for UI/UX.
- **Backend/Data Access**: GraphQL API layer built with Data API Builder (DAB), querying Cosmos DB and SQL Server.
- **Storage**:
  - Cosmos DB (SQL API) for primary task data.
  - Azure Blob Storage for media/uploads.
  - SQL Server for aggregated analytics.
- **Caching**: Redis for session management and caching frequently accessed data.
- **Authentication**: Basic login (e.g., Azure AD or custom JWT) to route users to their tenant's CELL instance.
- **Deployment**: Orchestrated via Azure Dev CLI (azd) from the management portal.
- **Routing/Branding**: Custom subdomains (e.g., tenant1.example.com) and header personalization based on captured tenant metadata.

The app will support multi-tenancy by:
- Using tenant IDs to partition data in Cosmos DB and SQL Server.
- Dynamically loading branding assets (e.g., logos, names) from Blob Storage or metadata.

## 4. Components Breakdown

### 4.1 Frontend
- **Technology**: .NET 9 Blazor (WebAssembly or Server mode) with Bootstrap 5 for responsive design.
- **Features**:
  - Login page for basic authentication.
  - Dashboard showing tenant name/business identity in the header (pulled from tenant metadata).
  - Task list view: Display, create