# TaskTracker GraphQL API Documentation

## Overview
This project uses HotChocolate to provide a modern GraphQL API for a multi-tenant task management system. The API supports queries, mutations, and subscriptions for real-time updates.

Note: For local/dev, the app can auto-seed demo tenants, users, categories, tags, and tasks when `SeedOnStartup=true` and `SkipCosmosInit=false` (see `docker-compose.yml`). This helps exercise the API without manual data entry.

## Authentication & Authorization
- All queries and mutations require authentication (JWT Bearer).
- SAS upload endpoint rate limiting is enforced (60 requests/minute). Other GraphQL endpoints are not rate-limited by default.

## Main Entities
- **TaskItem**: Represents a task with title, description, category, tags, assignees, etc.
- **Category**: Task categories per tenant.
- **Tag**: Tags for tasks.
- **Tenant**: Organization or workspace.
- **UserProfile**: User within a tenant.

## Key Queries
- `getTasks(tenantId, skip, take, ...)`: List tasks with pagination and filtering.
- `getTask(id, tenantId)`: Get a single task.
- `getCategories(tenantId)`, `getCategory(id, tenantId)`: List or get a category.
- `getTags(tenantId)`, `getTag(id, tenantId)`: List or get a tag.
- `getTenant(tenantId)`: Get tenant info.
- `getTenantUsers(tenantId)`: List users in a tenant.
- `searchTasks(...)`: Advanced search with pagination.
- `getTaskAnalytics(tenantId)`: Get task stats for dashboards.

## Key Mutations
- `createTask`, `updateTask`, `deleteTask`: CRUD for tasks.
- `createCategory`, `updateCategory`, `deleteCategory`: CRUD for categories.
- `createTag`, `updateTag`, `deleteTag`: CRUD for tags.
- `assignUsersToTask`, `unassignUsersFromTask`: Manage task assignees.
- `addTagsToTask`, `removeTagsFromTask`: Manage task tags.
- `addAttachmentToTask`, `removeAttachmentFromTask`: Manage attachments.
- `bulkArchiveTasks`, `bulkDeleteTasks`: Bulk operations.
- `createUser`, `updateUser`, `deleteUser`: User management.

## Subscriptions
- `onTaskCreated`, `onTaskUpdated`, `onTaskDeleted`: Real-time task events.

## Error Handling
- User-friendly errors are returned for invalid input (e.g., missing title).
- The API uses RFC 7807 ProblemDetails for API errors where applicable (e.g., SAS generation failures, validation problems). Include the `x-correlation-id` response header when reporting issues.

## Pagination
- All list queries support `skip` and `take` for offset pagination.

## Health Checks
- `/health` simple liveness endpoint.
- `/readyz` readiness checks (Cosmos DB, Blob Storage, Redis if configured).
- `/healthz` aggregate health.
- Dapr health: `/api/dapr/health` (when running with Dapr Compose).

## Infrastructure
- Azure Bicep and AZD for full infrastructure-as-code.

## Testing
- Unit test project with sample tests for services.

## Monitoring & Logging
- Application Insights and Log Analytics are provisioned in Bicep.
- Add structured logging in code for important events and errors.

## CORS & Security
- CORS is open in development; restrict in production.
- All sensitive endpoints require authentication.

---

For more details, see the code and schema files. Extend this documentation as your API evolves!
