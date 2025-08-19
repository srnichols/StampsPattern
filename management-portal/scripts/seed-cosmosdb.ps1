# Script to seed Cosmos DB with sample data for testing

$resourceGroupName = "rg-stamps-mgmt"
$cosmosAccountName = "cosmos-xgjwtecm3g5pi"
$databaseName = "stamps-control-plane"

Write-Host "Seeding Cosmos DB with sample data..."

# Sample tenant data
$sampleTenant = @{
    id = "tenant-001"
    name = "Sample Tenant 1"
    description = "A sample tenant for testing"
    cellId = "cell-001"
    status = "active"
    createdAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

# Sample cell data
$sampleCell = @{
    id = "cell-001"
    name = "West US Cell"
    description = "Primary cell in West US region"
    region = "westus2"
    status = "healthy"
    capacity = 1000
    tenantCount = 1
    createdAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

# Sample operation data
$sampleOperation = @{
    id = "op-001"
    type = "deployment"
    status = "completed"
    tenantId = "tenant-001"
    cellId = "cell-001"
    description = "Initial tenant deployment"
    startedAt = (Get-Date).AddHours(-1).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    completedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

# Create temporary JSON files
$sampleTenant | ConvertTo-Json | Out-File -FilePath "tenant.json" -Encoding UTF8
$sampleCell | ConvertTo-Json | Out-File -FilePath "cell.json" -Encoding UTF8
$sampleOperation | ConvertTo-Json | Out-File -FilePath "operation.json" -Encoding UTF8

try {
    # Insert sample data using Azure CLI
    Write-Host "Inserting sample tenant..."
    az cosmosdb sql container item create -g $resourceGroupName -a $cosmosAccountName -d $databaseName -c "tenants" --body ./tenant.json

    Write-Host "Inserting sample cell..."
    az cosmosdb sql container item create -g $resourceGroupName -a $cosmosAccountName -d $databaseName -c "cells" --body ./cell.json

    Write-Host "Inserting sample operation..."
    az cosmosdb sql container item create -g $resourceGroupName -a $cosmosAccountName -d $databaseName -c "operations" --body ./operation.json

    Write-Host "Sample data inserted successfully!"
}
finally {
    # Clean up temporary files
    Remove-Item -Path "tenant.json" -ErrorAction SilentlyContinue
    Remove-Item -Path "cell.json" -ErrorAction SilentlyContinue
    Remove-Item -Path "operation.json" -ErrorAction SilentlyContinue
}
