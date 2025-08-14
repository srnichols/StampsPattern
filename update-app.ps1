# Update Azure AD Application Configuration
$clientId = "d8f3024a-0c6a-4cea-af8b-7a7cd985354f"
$accessToken = "eyJ0eXAiOiJKV1QiLCJub25jZSI6IkxvM3N6cUhZc0VuRGxoT2M3ZVdlZTRPclNtbjlmZlNLWHQtaHo2TjhHTGsiLCJhbGciOiJSUzI1NiIsIng1dCI6IkpZaEFjVFBNWl9MWDZEQmxPV1E3SG4wTmVYRSIsImtpZCI6IkpZaEFjVFBNWl9MWDZEQmxPV1E3SG4wTmVYRSJ9.eyJhdWQiOiJodHRwczovL2dyYXBoLm1pY3Jvc29mdC5jb20iLCJpc3MiOiJodHRwczovL3N0cy53aW5kb3dzLm5ldC8zMGRkNTc1YS1iY2E3LTQ5MWItYWRmNi00MWQ1ZjM5Mjc1ZDQvIiwiaWF0IjoxNzU1MTUwNzk3LCJuYmYiOjE3NTUxNTA3OTcsImV4cCI6MTc1NTE1NjA3NSwiYWNjdCI6MCwiYWNyIjoiMSIsImFjcnMiOlsicDEiXSwiYWlvIjoiQWFRQVcvOFpBQUFBOE5qVFJsNWIxSnAzWkV2NkNpODFTMTlBSnJMdE5NcnN6QUhaMDhCUExsQ0s3UzFuR0F3dytCVjQwekJHUVFwU1M5YnNUOHVsa0cyY3hTVis4TlN5cmN4SFBtSmhUNjhWSU4xeHk2UjBvUG4vSXpuMXhFRzdDZWEyM04vYlhEa1dnYm1ZOU5udTNBeSs1Q0g5Z0JUYisrOVVBYjViYXBYV2ZzbkVtZXFCUnNLOHQvc2M5ZnI4WFpGMkU4emQzbVVNTDQ3VDV0U3IwTHU2VEQ3UnRaVjlZdz09IiwiYWx0c2VjaWQiOiIxOmxpdmUuY29tOjAwMDM3RkZFOEMzODM1NjMiLCJhbXIiOlsicHdkIiwibWZhIl0sImFwcF9kaXNwbGF5bmFtZSI6Ik1pY3Jvc29mdCBBenVyZSBDTEkiLCJhcHBpZCI6IjA0YjA3Nzk1LThkZGItNDYxYS1iYmVlLTAyZjllMWJmN2I0NiIsImFwcGlkYWNyIjoiMCIsImVtYWlsIjoic3JuaWNob2xzQGxpdmUuY29tIiwiZmFtaWx5X25hbWUiOiJOaWNob2xzIiwiZ2l2ZW5fbmFtZSI6IlNjb3R0IiwiaWRwIjoibGl2ZS5jb20iLCJpZHR5cCI6InVzZXIiLCJpcGFkZHIiOiI2Ny42MC4yMjguNzIiLCJuYW1lIjoiU2NvdHQgTmljaG9scyIsIm9pZCI6ImE4ZmE4NWZmLWY2NjgtNDRiOC05MTA5LTFiMzRlZWEzN2VjMCIsInBsYXRmIjoiMyIsInB1aWQiOiIxMDAzMjAwNTAwRUE3OThCIiwicmgiOiIxLkFjOEFXbGZkTUtlOEcwbXQ5a0hWODVKMTFBTUFBQUFBQUFBQXdBQUFBQUFBQUFEUEFPN1BBQS4iLCJzY3AiOiJBcHBsaWNhdGlvbi5SZWFkV3JpdGUuQWxsIEFwcFJvbGVBc3NpZ25tZW50LlJlYWRXcml0ZS5BbGwgQXVkaXRMb2cuUmVhZC5BbGwgRGVsZWdhdGVkUGVybWlzc2lvbkdyYW50LlJlYWRXcml0ZS5BbGwgRGlyZWN0b3J5LkFjY2Vzc0FzVXNlci5BbGwgZW1haWwgR3JvdXAuUmVhZFdyaXRlLkFsbCBvcGVuaWQgcHJvZmlsZSBVc2VyLlJlYWQuQWxsIFVzZXIuUmVhZFdyaXRlLkFsbCIsInNpZCI6IjAwN2MzY2M5LWVhODEtMjBhMi1iMjI1LTMxNzFkZTE2Y2Y3NyIsInN1YiI6Ilc3NzV1c0Iwb0N6dTJpVTZvMUxVWTlXRGxtSjZtdmZlZHFYQzNGdXdqeDQiLCJ0ZW5hbnRfcmVnaW9uX3Njb3BlIjoiTkEiLCJ0aWQiOiIzMGRkNTc1YS1iY2E3LTQ5MWItYWRmNi00MWQ1ZjM5Mjc1ZDQiLCJ1bmlxdWVfbmFtZSI6ImxpdmUuY29tI3NybmljaG9sc0BsaXZlLmNvbSIsInV0aSI6Im5hRXdrUTI1NzBPb2ZISnRaR2NFQUEiLCJ2ZXIiOiIxLjAiLCJ3aWRzIjpbIjYyZTkwMzk0LTY5ZjUtNDIzNy05MTkwLTAxMjE3NzE0NWUxMCIsImI3OWZiZjRkLTNlZjktNDY4OS04MTQzLTc2YjE5NGU4NTUwOSJdLCJ4bXNfY2MiOlsiQ1AxIl0sInhtc19mdGQiOiJXUkFsWG85bk44TmgxQWw5M29halppUE9CdG56QUdGNVRLTGd1NzZhYXNZQmRYTnViM0owYUMxa2MyMXoiLCJ4bXNfaWRyZWwiOiIxIDQiLCJ4bXNfc3QiOnsic3ViIjoia2tpb1hqRG4tNnk5VmVVc01QeHk0TlQ5dEhlQ1J6aVk0S2YybUdlN2xvQSJ9LCJ4bXNfdGNkdCI6MTc1NDc4ODY0MX0.jkRBDHeA_oQB0OB0NfTYoH__JTCzX6YpumdR8twgdbYdieKpRGQxnT5cYnw4-ipIxMMNcJaxfe5Nv2WrBMOOjoJSYxg893pbp46SgkXA5LRJVuTh1cnoFAZZaEKoq1kxQBoMCW1QvGYsRDdO7gdKiFU5L6jW2-QD2NLP3mHgrpkICcK9Axmwn6eAfHom50UY7cSHvB0egvqUDKHnFPwxywlb6p7aa1nJW5-aeMGLLfemcRq4xJiKDDAEd6VcyYIB30rc5e1cwBcO_vhL93BXwTM46xR_CanxBpAOpoMFsxqtxCSmnmzh-3SQedxX78hpC6954POW-14gwZlg7tW2AA"

$uri = "https://graph.microsoft.com/v1.0/applications/$clientId"
$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type" = "application/json"
}

$body = @{
    web = @{
        redirectUris = @("https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io/signin-oidc")
        logoutUrl = "https://ca-stamps-portal.wittywave-3d4ef36b.westus2.azurecontainerapps.io/signout-callback-oidc"
        implicitGrantSettings = @{
            enableIdTokenIssuance = $true
            enableAccessTokenIssuance = $true
        }
    }
} | ConvertTo-Json -Depth 3

Write-Host "Updating Azure AD application..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri $uri -Method PATCH -Headers $headers -Body $body
    Write-Host "✅ Successfully updated Azure AD application!" -ForegroundColor Green
    Write-Host "   - ID tokens enabled" -ForegroundColor White
    Write-Host "   - Redirect URI configured" -ForegroundColor White
} catch {
    Write-Host "❌ Failed to update Azure AD application:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody" -ForegroundColor Red
    }
}
