# Probes local Azure Functions endpoints for a quick smoke test
param(
    [int] $Port = 7071
)

$ErrorActionPreference = 'Stop'

function Test-Endpoint {
    param(
        [string] $Path
    )
    $uri = "http://localhost:$Port$Path"
    try {
        Write-Host "GET $uri" -ForegroundColor Cyan
        $resp = Invoke-WebRequest -UseBasicParsing -Uri $uri -Method GET -TimeoutSec 10
        Write-Host ("Status: {0} {1}" -f [int]$resp.StatusCode, $resp.StatusDescription)
        return $true
    }
    catch {
        Write-Warning "Failed: $uri"
        Write-Host $_.Exception.Message
        return $false
    }
}

$results = @()
$results += Test-Endpoint -Path "/api/health"
$results += Test-Endpoint -Path "/api/api/info"
$results += Test-Endpoint -Path "/api/swagger/ui"

if ($results -contains $false) {
    Write-Error "One or more endpoints failed. Check the Functions host output."
    exit 1
}

Write-Host "All endpoints responded successfully." -ForegroundColor Green
exit 0
