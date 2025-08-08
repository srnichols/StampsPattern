# Management Portal

Run locally with Aspire AppHost. Defaults to in-memory data;
set DAB_GRAPHQL_URL to point to your Data API Builder GraphQL endpoint to use real data.

## Local Run
- Build AppHost: dotnet build management-portal/AppHost
- Run AppHost: dotnet run --project management-portal/AppHost
- Portal URL: http://localhost:8081

## Config
- DAB_GRAPHQL_URL: e.g. http://localhost:8082/graphql

## Switch Data Source
- Leave DAB_GRAPHQL_URL empty to use in-memory data
- Set DAB_GRAPHQL_URL to use GraphQL
