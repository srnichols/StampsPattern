JSON Fixtures

Put JSON files here to seed via `/dev/seed-json` without rebuilding. Supported files (arrays of objects):

- tenants.json
	- { id: string, name: string, subdomain?: string, primaryColor?: string, isActive?: bool, createdAtUtc?: string }
- users.json
	- { id?: string, tenantId: string, displayName: string, email: string, createdAtUtc?: string, lastLoginUtc?: string }
- categories.json
	- { id?: Guid, tenantId: string, name: string, sortOrder?: number, createdAtUtc?: string }
- tags.json
	- { id?: Guid, tenantId: string, name: string, createdAtUtc?: string }
- tasks.json
	- { id?: Guid, tenantId: string, title: string, description?: string, categoryId?: Guid, priority?: 1|2|3, isArchived?: bool, dueDate?: string, icon?: string, attachments?: [], assigneeUserIds?: string[], createdByUserId: string, createdAtUtc?: string, updatedAtUtc?: string, tagNames?: string[] }
- settings.json
	- { id: "settings", tenantId: string, dashboardTitle?: string, themeColor?: string, domain?: string, updatedAtUtc?: string }

How to run:
- Initialize: GET /dev/init-cosmos
- Seed: POST /dev/seed-json
- Verify: GET /dev/seed-status?format=html

Notes:
- JSON fixtures are the single supported seeding method. GraphQL-based seeding has been removed.
