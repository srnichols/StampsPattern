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

function Start-Dab($network, $containerName, $dabPort, $dabConfigPath, $cosmosConn) {
    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq $containerName }
    if ($running) { return }
    $configAbs = Resolve-Path $dabConfigPath
    docker run -d --name $containerName --network $network `
        -e ASPNETCORE_URLS=http://+:${dabPort} `
        -e COSMOS_CONNECTION_STRING="$cosmosConn" `
        -p ${dabPort}:${dabPort} `
        -v "${configAbs}:/App/dab-config.json:ro" `
        mcr.microsoft.com/data-api-builder:latest `
        dab start --host 0.0.0.0 --config /App/dab-config.json | Out-Null
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
$dabContainer = 'stamps-dab'

Start-CosmosEmulator -network 'stamps-net' -containerName $cosmosContainer -hostPort $CosmosHostPort

# Wait for emulator certificate endpoint as readiness signal
Wait-Http -url "https://localhost:${CosmosHostPort}/_explorer/emulator.pem" -timeoutSec 180

$cosmosConnForContainers = 'AccountEndpoint=https://stamps-cosmos:8081/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==;'
$cosmosConnForHost = "AccountEndpoint=https://localhost:${CosmosHostPort}/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==;"

Start-Dab -network 'stamps-net' -containerName $dabContainer -dabPort $DabPort -dabConfigPath '.\management-portal\dab\dab-config.json' -cosmosConn $cosmosConnForContainers

# Install emulator certificate into DAB container trust store
$pem = Join-Path $env:TEMP "cosmos-emulator.pem"
try { Invoke-WebRequest -Uri "https://localhost:${CosmosHostPort}/_explorer/emulator.pem" -OutFile $pem -SkipCertificateCheck } catch {}
if (Test-Path $pem) {
    docker cp $pem ${dabContainer}:/usr/local/share/ca-certificates/cosmos-emulator.crt | Out-Null
    docker exec ${dabContainer} update-ca-certificates | Out-Null
}

# Wait for DAB GraphQL
Wait-Http -url "http://localhost:${DabPort}/graphql" -timeoutSec 120

Run-Seeder -cosmosHostConn $cosmosConnForHost

Run-Portal -dabPort $DabPort -portalPort $PortalPort
