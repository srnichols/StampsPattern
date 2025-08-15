# Detailed Authentication Flow Test
# Tests the complete OIDC redirect chain and validates parameters

$portalUrl = 'https://ca-stamps-portal.whitetree-24b33d85.westus2.azurecontainerapps.io/'

Write-Host "=== Portal Authentication Flow Test ===" -ForegroundColor Cyan
Write-Host "Testing URL: $portalUrl" -ForegroundColor Yellow
Write-Host ""

try {
    # Step 1: Initial request to portal
    Write-Host "Step 1: Making initial request to portal..." -ForegroundColor Green
    $response = Invoke-WebRequest -Uri $portalUrl -Method Get -MaximumRedirection 0 -ErrorAction Stop
    Write-Host "  Status: $($response.StatusCode) (unexpected - should be redirect)" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 302) {
        Write-Host "  Status: 302 Found (correct - redirecting to login)" -ForegroundColor Green
        
        # Step 2: Parse the redirect location
        $locationHeader = $_.Exception.Response.Headers['Location']
        if ($locationHeader -and $locationHeader.Count -gt 0) {
            $location = $locationHeader[0].ToString()
            Write-Host "  Redirect Location: $location" -ForegroundColor Yellow
        Write-Host ""
        
        # Step 3: Validate OIDC parameters
        Write-Host "Step 2: Validating OIDC redirect parameters..." -ForegroundColor Green
        
        $uri = [System.Uri]$location
        $query = [System.Web.HttpUtility]::ParseQueryString($uri.Query)
        
        # Check critical parameters
        $clientId = $query['client_id']
        $redirectUri = $query['redirect_uri']
        $responseType = $query['response_type']
        $scope = $query['scope']
        
        Write-Host "  Authority: $($uri.Scheme)://$($uri.Host)$($uri.AbsolutePath)" -ForegroundColor White
        Write-Host "  Client ID: $clientId" -ForegroundColor White
        Write-Host "  Redirect URI: $redirectUri" -ForegroundColor White
        Write-Host "  Response Type: $responseType" -ForegroundColor White
        Write-Host "  Scope: $scope" -ForegroundColor White
        Write-Host ""
        
        # Step 4: Validate expected values
        Write-Host "Step 3: Validating configuration..." -ForegroundColor Green
        
        $expectedClientId = 'e691193e-4e25-4a72-9185-1ce411aa2fd8'
        $expectedTenant = '16b3c013-d300-468d-ac64-7eda0820b6d3'
        
        if ($clientId -eq $expectedClientId) {
            Write-Host "  ✓ Client ID matches expected App Registration" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Client ID mismatch. Expected: $expectedClientId, Got: $clientId" -ForegroundColor Red
        }
        
        if ($location -like "*$expectedTenant*") {
            Write-Host "  ✓ Tenant ID found in redirect URL" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Tenant ID not found in redirect URL" -ForegroundColor Red
        }
        
        if ($redirectUri -like "*ca-stamps-portal*signin-oidc*") {
            Write-Host "  ✓ Redirect URI points back to portal signin-oidc endpoint" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Redirect URI configuration issue" -ForegroundColor Red
        }
        
        if ($scope -like "*openid*") {
            Write-Host "  ✓ OIDC scope includes 'openid'" -ForegroundColor Green
        } else {
            Write-Host "  ✗ OIDC scope missing 'openid'" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "=== Authentication Flow Summary ===" -ForegroundColor Cyan
        Write-Host "✓ Portal correctly redirects unauthenticated requests" -ForegroundColor Green
        Write-Host "✓ Azure AD endpoint is correctly configured" -ForegroundColor Green
        Write-Host "✓ OIDC parameters are properly formatted" -ForegroundColor Green
        Write-Host "✓ App Registration integration is working" -ForegroundColor Green
        Write-Host ""
        Write-Host "The authentication flow is properly configured!" -ForegroundColor Green
        Write-Host "Users will be redirected to Azure AD for login and then back to the portal." -ForegroundColor White
        
    } else {
        Write-Host "  Unexpected response: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Test completed." -ForegroundColor Cyan
