# Quick HTTP/HTTPS smoke test to App Gateway IPs or FQDNs
param(
  [Parameter(Mandatory=$true)][string[]]$Targets
)

$ErrorActionPreference = 'SilentlyContinue'

$rows = foreach($t in $Targets){
  $p80 = Test-NetConnection -ComputerName $t -Port 80 -WarningAction SilentlyContinue
  $p443 = Test-NetConnection -ComputerName $t -Port 443 -WarningAction SilentlyContinue
  [pscustomobject]@{
    Target = $t
    TCP80 = if($p80.TcpTestSucceeded){'open'}else{'closed'}
    TCP443 = if($p443.TcpTestSucceeded){'open'}else{'closed'}
  }
}
$rows | Format-Table -AutoSize

foreach($t in $Targets){
  try{
    Write-Host "\n==== HTTP HEAD $t ====" -ForegroundColor Yellow
    $resp = curl.exe -sI "http://$t/" | Out-String
    Write-Host $resp
  } catch {}
  try{
    Write-Host "\n==== HTTPS HEAD $t ====" -ForegroundColor Yellow
    $resp = curl.exe -skI "https://$t/" | Out-String
    Write-Host $resp
  } catch {}
}
