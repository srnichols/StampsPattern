# Data Access Layer (DAL) Overview

This project uses HotChocolate GraphQL as the primary API surface, backed by Cosmos DB (SQL API) and simple service classes for blob storage and caching.

## Components

- GraphQL Server (HotChocolate)
  - Endpoint: `/graphql`
  - Supports queries, mutations, and subscriptions
  - Multi-tenant: all operations are scoped by `tenantId`
- Cosmos DB
  - Database name: `CosmosDb:DatabaseName` (default `TaskTrackerDb`)
  - Containers: `Tenants` (pk: `/id`), `Users` (pk: `/tenantId`), `Categories` (pk: `/tenantId`), `Tags` (pk: `/tenantId`), `Tasks` (pk: `/tenantId`)
  - Client options: Gateway mode with permissive certs for the emulator and `LimitToEndpoint=true` for container networking
- Blob Storage
  - Service: `BlobStorageService` generates SAS for uploads via `POST /api/upload/sas`
  - Options: `BlobOptions` (connection string + `ContainerName`), validated on startup
- Caching
  - Redis in container; falls back to in-memory cache when absent
  - Options: `RedisOptions` (connection string)

## Key Files

- `Program.cs`: registers services and options (CosmosOptions, BlobOptions, RedisOptions), maps `/graphql`, `/api/upload/sas` (rate-limited), `/health`, and dev-only `/dev/seed-status` + `/dev/seed-json`; initializes Cosmos and optional seed; enables ProblemDetails and correlation-id enrichment.
- `Services/CosmosDbService.cs`: data access helpers used by resolvers/services
- `Services/BlobStorageService.cs`: SAS token generation
- `Services/AuthenticationService.cs`: demo auth/tenant context
- `Models/*`: POCOs for Tasks, Categories, Tenants
- `docs/API_DOCUMENTATION.md`: GraphQL operations and usage

## Development

- Local stack runs via Docker Compose: app + Cosmos Emulator + Azurite + Redis
- Optional JSON seed is enabled by env flags in `docker-compose.yml`:
  - `SkipCosmosInit=false`
  - `SeedOnStartup=true`
- Verify seed: `GET /dev/seed-status` (seed with `POST /dev/seed-json`)

## Notes

- Prefer queries scoped to `tenantId` for performance and isolation
- Keep container partition keys aligned with model lookups and resolvers
- Restrict CORS and JWT configuration for non-dev environments
