# Management Portal

Run locally with one command or via the AppHost. Defaults to in-memory data; set DAB_GRAPHQL_URL to point to your Data API Builder GraphQL endpoint to use real data.

## Local Run (one command)
- Start: pwsh -File .\scripts\run-local.ps1
- Stop: pwsh -File .\scripts\stop-local.ps1
- Portal: http://localhost:8081
- GraphQL: http://localhost:8082/graphql
- Cosmos Emulator: https://localhost:8085

## Local Run (AppHost)
- Build AppHost: dotnet build management-portal/AppHost
- Run AppHost: dotnet run --project management-portal/AppHost
- Portal URL: http://localhost:8081

## Config
- DAB_GRAPHQL_URL: e.g. http://localhost:8082/graphql

## Switch Data Source
- Leave DAB_GRAPHQL_URL empty to use in-memory data
- Set DAB_GRAPHQL_URL to use GraphQL

## CRUD
- Tenants page supports create/update/delete when GraphQL is enabled (DAB provides mutations).
- For in-memory mode, operations affect only the running process.
