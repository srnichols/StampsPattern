#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Stop DAB host process if running
$pidFile = Join-Path $PSScriptRoot '..\.dab.pid'
if (Test-Path $pidFile) {
  try {
    $pid = Get-Content $pidFile | Select-Object -First 1
    if ($pid) {
      Write-Host "Stopping DAB process PID $pid"
      Stop-Process -Id $pid -ErrorAction SilentlyContinue
    }
  } catch {}
  Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}

# Stop containers
$containers = @('stamps-cosmos')
foreach ($c in $containers) {
  if (docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq $c }) {
    Write-Host "Stopping and removing $c"
    docker rm -f $c | Out-Null
  }
}
