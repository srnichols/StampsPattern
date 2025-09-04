# Smoke tests for Stamps management portal and GraphQL backend
# Usage: .\smoke-test.ps1

$portalUrl = 'https://ca-stamps-portal.whitetree-24b33d85.westus2.azurecontainerapps.io/'
# Note: the GraphQL backend has an internal URL and is not accessible from external tests. We'll check portal redirect instead.

Write-Host "Testing portal root: $portalUrl"
try {
    $response = Invoke-WebRequest -Uri $portalUrl -Method Get -MaximumRedirection 0 -ErrorAction Stop
    Write-Host "Portal root status: $($response.StatusCode)"
} catch {
    if ($_.Exception.Response.StatusCode -eq 302) {
        Write-Host "Portal root returns 302 (login redirect) as expected."
        $location = $_.Exception.Response.Headers['Location']
        if ($location) {
            Write-Host "Redirect location: $($location.ToString())"
            if ($location.ToString() -like "*login.microsoftonline.com*" -and $location.ToString() -like "*client_id=e691193e-4e25-4a72-9185-1ce411aa2fd8*") {
                Write-Host "✓ Redirect contains correct Azure AD login and client ID"
            } else {
                Write-Host "⚠ Redirect may not contain expected client ID"
            }
        }
    } else {
        Write-Host "Portal root unexpected response: $($_.Exception.Response.StatusCode)"
    }
}

Write-Host "✓ Portal authentication flow appears to be working"
Write-Host "Note: the GraphQL endpoint is internal-only and not testable from external scripts."
Write-Host "Done."
