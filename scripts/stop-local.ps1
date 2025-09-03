#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# DAB is not managed by this script. If you started DAB manually, stop it separately.

# Stop containers
$containers = @('stamps-cosmos')
foreach ($c in $containers) {
  if (docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq $c }) {
    Write-Host "Stopping and removing $c"
    docker rm -f $c | Out-Null
  }
}
