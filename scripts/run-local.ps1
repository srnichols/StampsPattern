#requires -Version 7.0
param(
    [int]$CosmosHostPort = 8085,
    [int]$DabPort = 8082,
    [int]$PortalPort = 8081
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-Docker() {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker is required. Please install Docker Desktop and ensure it is running.'
    }
}

function Ensure-Network($name) {
    $exists = docker network ls --format '{{.Name}}' | Where-Object { $_ -eq $name }
    if (-not $exists) {
        docker network create $name | Out-Null
    }
}

function Ensure-DabTool() {
    # Data API Builder (dab) is no longer started automatically by the local scripts.
    return
}

function Start-CosmosEmulator($network, $containerName, $hostPort) {
    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq $containerName }
    if ($running) { return }

    docker run -d --name $containerName --network $network `
        -e AZURE_COSMOS_EMULATOR_ENABLE_TELEMETRY=false `
        -e AZURE_COSMOS_EMULATOR_PARTITION_COUNT=3 `
        -e AZURE_COSMOS_EMULATOR_ENABLE_DATA_PERSISTENCE=true `
        --cap-add=NET_ADMIN `
        -p ${hostPort}:8081 `
        mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:latest | Out-Null
}

function Wait-Http($url, $timeoutSec = 120) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
        try {
            Invoke-WebRequest -Uri $url -Method Head -SkipCertificateCheck -TimeoutSec 5 | Out-Null
            return
        } catch {
            Start-Sleep -Seconds 2
        }
    }
    throw "Timeout waiting for $url"
}

function Import-EmulatorCert() {
    $pemUrl = "https://localhost:${CosmosHostPort}/_explorer/emulator.pem"
    $pem = Join-Path $env:TEMP "cosmos-emulator.pem"
    try { Invoke-WebRequest -Uri $pemUrl -OutFile $pem -SkipCertificateCheck } catch {}
    if (Test-Path $pem) {
        try {
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($pem)
        } catch {
            # Convert PEM to CER by wrapping in certutil
            $cer = Join-Path $env:TEMP "cosmos-emulator.cer"
            certutil -encode $pem $cer | Out-Null
            $pem = $cer
        }
        try {
            Import-Certificate -FilePath $pem -CertStoreLocation Cert:\CurrentUser\Root | Out-Null
            Write-Host 'Imported Cosmos emulator certificate into CurrentUser\\Root.'
        } catch {
            Write-Warning 'Failed to import emulator certificate. You may need to accept the cert manually.'
        }
    }
}

function Start-DabHost($dabPort, $dabConfigPath, $cosmosConn) {
    Write-Host 'Skipping automatic DAB startup: use an external DAB instance or the built-in Hot Chocolate endpoint.'
}

function Run-Seeder($cosmosHostConn) {
    Write-Host 'Seeding sample data...'
    $env:COSMOS_CONNECTION_STRING = $cosmosHostConn
    dotnet run --project .\management-portal\Seeder\Seeder.csproj | Write-Host
}

function Run-Portal($dabPort, $portalPort) {
    Write-Host "Starting Portal on http://localhost:$portalPort ..."
    $env:DAB_GRAPHQL_URL = "http://localhost:${dabPort}/graphql"
    $env:ASPNETCORE_URLS = "http://+:${portalPort}"
    dotnet run --project .\management-portal\src\Portal\Portal.csproj
}

# Main
Ensure-Docker
Ensure-Network 'stamps-net'

$cosmosContainer = 'stamps-cosmos'

Start-CosmosEmulator -network 'stamps-net' -containerName $cosmosContainer -hostPort $CosmosHostPort

# Wait for emulator certificate endpoint as readiness signal (emulator can be slow on first start)
try {
    Wait-Http -url "https://localhost:${CosmosHostPort}/_explorer/emulator.pem" -timeoutSec 420
}
catch {
    Write-Warning "Cosmos Emulator readiness check timed out. Showing container status and recent logs:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | Write-Host
    docker logs $cosmosContainer --tail 200 | Write-Host
    throw
}

$cosmosConnForHost = "AccountEndpoint=https://localhost:${CosmosHostPort}/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==;"

# Import emulator certificate to Windows trust so host DAB can connect
Import-EmulatorCert

# NOTE: DAB is no longer started by this script. The portal hosts a Hot Chocolate GraphQL endpoint.
Run-Seeder -cosmosHostConn $cosmosConnForHost

Run-Portal -dabPort $DabPort -portalPort $PortalPort
