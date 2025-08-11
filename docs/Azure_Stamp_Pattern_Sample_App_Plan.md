# Sample Application Plan for Azure Stamp Pattern Infrastructure Framework

## 1. Introduction

This document outlines a detailed plan for developing and integrating a sample application into the Azure Stamp Pattern infrastructure framework. The sample app will serve as a demonstration tool to showcase the functionality of the framework across all types of CELLs (e.g., compute, storage, networking, and hybrid CELLs, assuming standard Stamp Pattern configurations). It will represent demo customer/tenant instances, highlighting multi-tenancy features such as unique URLs, subdomains, routing, and client branding.

The application will be a simple user task tracking app, designed with minimal functionality to prove the concept without unnecessary complexity. To add a bit more flare while staying lightweight, the app will support task categories, sharing tasks with team members in the same tenant, priority ranking (high, mid, low) plus an archive state, optional due dates, and keyword tagging with search. No code will be built at this stage; this plan serves as a reference for future implementation.

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
- Tasks can be grouped by category and filtered by category.
- Tasks can be shared among team members of the same tenant with access control enforced per tenant.
- Tasks support priority ranking (high, mid, low) and an archive state; archived tasks are hidden by default with a toggle to view.
- Tasks can have an optional due date; overdue tasks are visually highlighted.
- Tag-based keyword search returns relevant tasks quickly (by tag and basic text match in title/description).

## 3. High-Level Architecture Overview

The sample app will follow a microservices-inspired architecture, containerized for deployment into CELLs. It will consist of a frontend, backend/data access layer, and supporting services. The app will be deployed as a single container app bundle, with dependencies on Azure-managed services.

### Architecture Diagram (Conceptual)
(Note: In future documentation, include a visual diagram using tools like Draw.io or Azure Architecture Icons.)

- **Frontend**: .NET 9 Blazor app with Bootstrap 5 for UI/UX.
- **Backend/Data Access**: GraphQL API layer built with Data API Builder (DAB), querying Cosmos DB and SQL Server.
- **Storage**:
  - Cosmos DB (SQL API) for primary task data.
  - Azure Blob Storage for media/uploads (task attachments). Blob URIs are persisted with tasks in Cosmos DB.
  - SQL Server for aggregated analytics.
- **Caching**: Redis for session management and caching frequently accessed data.
- **Authentication**: Basic login (e.g., Microsoft Entra ID or custom JWT) to route users to their tenant's CELL instance.
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
  - Task list view: Display, create, edit, delete tasks.
  - Category grouping and filtering: View tasks grouped by category; filter by a selected category.
  - Priority and archive: Inline set priority (high, mid, low); archive/unarchive tasks; hide archived by default with a toggle.
  - Due date: Optional date picker; show due date in list; visually mark overdue tasks.
  - Tagging: Add/remove tags on a task; tokenized tag chips with typeahead suggestions.
  - Sharing: Assign one or more team members (within the same tenant) to a task.
  - Search and filters: Quick search bar for tags and basic text; filters for category, priority, due (e.g., today/this week/overdue), and archived state.
  - Attachments: Upload/remove media files (e.g., images, documents) to tasks; show thumbnail/filename list; download/view.
  - Task icon/emoji: Pick an icon/emoji from a curated set; show icon on list rows and detail.

### 4.2 Backend/API
- **Technology**: Data API Builder (GraphQL) over Cosmos DB (SQL API) and SQL for simple analytics.
- **Core entities** (GraphQL types):
  - Task: id, tenantId, title, description, categoryId?, priority, isArchived, dueDate?, icon?, attachments[], createdByUserId, assigneeUserIds[], createdAtUtc, updatedAtUtc
  - Category: id, tenantId, name, sortOrder
  - Tag: id, tenantId, name
  - TaskTag (join): taskId, tagId
  - Attachment (embedded on Task): id, blobUri, fileName, contentType, sizeBytes, uploadedByUserId, uploadedAtUtc
- **Authorization & tenancy**:
  - All reads/writes scoped by tenantId derived from the user’s identity claims.
  - Row-level security via DAB policies: users can access tasks in their tenant; task edits allowed to creator or assignees.
  - Attachments upload: client uploads via secure SAS to a tenant-scoped container or prefix; resulting blobUri is stored on the Task in Cosmos.

### 4.3 Data Model (minimal)
- Task
  - id (GUID), tenantId (string/UUID), title (string), description (string, optional)
  - categoryId (GUID, optional)
  - priority (enum: High | Mid | Low)
  - isArchived (bool, default false)
  - dueDate (datetime, optional)
  - icon (string, optional; emoji or icon key from curated set)
  - attachments (array of Attachment)
  - assigneeUserIds (array of strings/UUIDs, same-tenant users)
  - createdByUserId (string/UUID), createdAtUtc (datetime), updatedAtUtc (datetime)
- Category
  - id (GUID), tenantId, name (string), sortOrder (int)
- Tag
  - id (GUID), tenantId, name (string)
- TaskTag (many-to-many)
  - taskId (GUID), tagId (GUID)
 - Attachment (embedded)
   - id (GUID), blobUri (string), fileName (string), contentType (string), sizeBytes (int), uploadedByUserId (string/UUID), uploadedAtUtc (datetime)

Notes:
- Keep user profile minimal; reference users by their directory object identifier from Microsoft Entra ID.
- Avoid storing PII; rely on claims for display names where necessary.

### 4.4 Search & Filtering
- Client-side search backed by GraphQL query filters:
  - Filter by categoryId, priority, isArchived, dueDate ranges (e.g., overdue, today, next 7 days).
  - Tag search via tag names and the TaskTag join; basic contains match on title/description.
  - Attachment filter: filter by hasAttachment true/false.
- Future-friendly: Optionally integrate Azure AI Search if richer full-text or scoring is needed later, but not required for the sample.

## 5. Acceptance Criteria

### 5.1 Categories
- Users can create, rename, and delete categories within their tenant.
- Tasks can be assigned zero or one category; uncategorized tasks appear under “Uncategorized.”
- Category filter shows only tasks within the selected category.
- Group by category view clusters tasks under category headings.
- Category operations and visibility are tenant-scoped.

### 5.2 Sharing (intra-tenant)
- Task creator can assign or unassign one or more team members from the same tenant.
- Only the creator or current assignees can edit a shared task.
- Non-assignees in the same tenant cannot edit the task; visibility aligns with sharing intent (visible in shared views).
- All read/write operations are tenant-scoped; cross-tenant access is not possible.

### 5.3 Priority and Archive
- Users can set priority to High, Mid, or Low from the list or detail view.
- Archived tasks are excluded from the default list and can be revealed via a “Show archived” toggle.
- Unarchiving a task returns it to the active list with its prior priority and metadata intact.

### 5.4 Due Date
- Tasks support an optional due date.
- Tasks past their due date are visually highlighted as overdue.
- Date quick-filters (Today, This Week, Overdue) return the correct task sets.

### 5.5 Tagging and Search
- Users can add and remove tag chips on a task with typeahead suggestions for existing tags.
- Searching by keyword matches tag names and performs a basic contains match on title and description.
- Search and filters can be combined (e.g., tags + category + priority + due window + archived state).
- Search results are tenant-scoped and return within a reasonable latency for a sample app.

### 5.6 Multi-Tenancy & Security
- Every entity (Task, Category, Tag) is stamped with tenantId and enforced at the API layer.
- Users only see and modify data from their tenant; cross-tenant access is blocked by policy.

### 5.7 Attachments
- Users can upload and remove attachments from a task; supported common media/document types.
- Uploaded files are stored in Azure Blob Storage under a tenant-scoped container or prefix.
- The blobUri, filename, content type, size, and audit info are persisted with the task in Cosmos DB.
- Only same-tenant users with access to the task can list/download attachments.
- Uploads use time-limited SAS; direct blob access without SAS is blocked.

### 5.8 Task Icon/Emoji
- Users can select an icon/emoji from a curated set.
- Selected icon displays on task rows and task detail.
- Icon value persists with the task and is optional.

## 6. UI Wireframes (ASCII Sketches)

### 6.1 Dashboard / Task List

```
+----------------------------------------------------------------------------------+
| Brand/Logo  | Tenant: Contoso North  | [ Search tasks & tags... ]  ( + New Task ) |
+----------------------------------------------------------------------------------+
| Nav:  All  |  My Tasks  |  Shared  |  Archived  |  Settings                         |
| Filters: Category [▼]  Priority [▼]  Due [ All | Today | This Week | Overdue ]     |
+----------------------------------------------------------------------------------+
| Category: Engineering (3)                                                            |
| [ ] ⭐ ■ High  Migrate API to v2                 Due: 2025-08-20   📎 2  #migration #api |
| [ ] ■ Mid   Update README                        Due: —            #docs            |
| [ ] ■ Low   Clean up backlog tags                Due: —            #hygiene         |
|                                                                                      |
| Category: Uncategorized (1)                                                           |
| [ ] 📝 ■ Mid Draft Q3 planning notes             Due: 2025-08-15   📎 0  #planning   |
+----------------------------------------------------------------------------------+
Legend: [ ] checkbox; ■ priority color chip (High/Mid/Low); #tag token; ⭐/📝 icon; 📎 attachment count
```

### 6.2 Task Detail / Drawer

```
+-------------------------------- Task: Migrate API to v2 --------------------------------+
| Title: [ Migrate API to v2                                     ]  Priority: [ High ▼ ]  |
| Icon: [ ⭐ ▼ ]   Category: [ Engineering ▼ ]   Due: [ 2025-08-20 ▾ ]  Archived: ( ) No ( ) Yes |
| Assignees (same-tenant): [ add @user ]  [ @alex.j | @maria.s ]                           |
| Tags: [ #migration ] [ #api ]  [+ add tag]                                              |
|-----------------------------------------------------------------------------------------|
| Description:                                                                            |
| [ Update to v2 endpoints and roll out gradually. Validate with canary traffic.       ] |
|-----------------------------------------------------------------------------------------|
| Attachments:  [ Upload file ]   [ 📄 api-v2-plan.pdf (112 KB) ]  [ 🖼️ diagram.png (340 KB) ] |
|-----------------------------------------------------------------------------------------|
| ( Save )   ( Archive )   ( Unarchive )   ( Delete )                                     |
+-----------------------------------------------------------------------------------------+
```
