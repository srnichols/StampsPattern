# Insert data through Data API Builder (DAB)
Write-Host "Starting data insertion through DAB..." -ForegroundColor Green

$dabUrl = "https://ca-stamps-dab.lemonforest-88e81141.westus2.azurecontainerapps.io"

# Function to insert via DAB
function Insert-ViaDab {
    param(
        [string]$entityName,
        [hashtable]$document
    )
    
    $uri = "$dabUrl/graphql"
    $headers = @{
        "Content-Type" = "application/json"
    }
    
    # Convert hashtable values to proper GraphQL format
    $docJson = $document | ConvertTo-Json -Depth 10 -Compress
    
    # Create GraphQL mutation
    $mutation = @"
mutation {
  create$entityName(item: $docJson) {
    id
  }
}
"@

    $body = @{
        query = $mutation
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body $body
        if ($response.errors) {
            Write-Host "✗ GraphQL errors for $($document.id): $($response.errors | ConvertTo-Json)" -ForegroundColor Red
            return $false
        } else {
            Write-Host "✓ Inserted via DAB: $($document.id)" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "✗ Failed to insert $($document.id) via DAB: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Check DAB health first
try {
    $healthResponse = Invoke-RestMethod -Uri "$dabUrl/health" -Method GET
    Write-Host "✓ DAB is healthy: $($healthResponse.status)" -ForegroundColor Green
} catch {
    Write-Host "✗ DAB health check failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nInserting sample data via DAB..." -ForegroundColor Yellow

# Test with simple cell data
$cell1 = @{
    id = "cell-eastus-01"
    cellId = "cell-eastus-01"
    cellName = "East US Cell 01"
    region = "eastus"
    backendPool = "eastus-pool-01.stamps.com"
    maxCapacity = 1000
    currentTenants = 2
    isActive = $true
    cellType = "Standard"
}

Insert-ViaDab -entityName "Cell" -document $cell1

Write-Host "`nData insertion attempt completed!" -ForegroundColor Green
Write-Host "Portal URL: https://ca-stamps-portal.lemonforest-88e81141.westus2.azurecontainerapps.io" -ForegroundColor Cyan
