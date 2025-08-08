# AppHost (Aspire)

This AppHost composes:
- Portal (http://localhost:8081)
- Data API Builder (http://localhost:8082)

Provide a Cosmos connection string for DAB:
- Set COSMOS_CONNECTION_STRING in your environment
- Example (emulator): AccountEndpoint=https://localhost:8081/;AccountKey=...;

Run:
- dotnet run --project management-portal/AppHost
