# Assign DNS labels to Application Gateway Public IPs (friendly FQDNs)
param(
  [string]$SubscriptionId = '2fb123ca-e419-4838-9b44-c2eb71a21769',
  [string]$ResourceGroup = 'rg-stamps-host',
  [string]$Wus2LabelPrefix = 'agw-wus2-tst',
  [string]$Wus3LabelPrefix = 'agw-wus3-tst'
)

$ErrorActionPreference = 'Stop'
az account set --subscription $SubscriptionId | Out-Null

$pips = az network public-ip list -g $ResourceGroup -o json | ConvertFrom-Json
if(-not $pips){ Write-Error "No public IPs found in $ResourceGroup"; exit 1 }

function Set-Label {
  param($pipName, $prefix)
  $label = "$prefix-" + (Get-Random -Maximum 9999).ToString('0000')
  Write-Host "Setting DNS label for $pipName -> $label" -ForegroundColor Cyan
  az network public-ip update -g $ResourceGroup -n $pipName --dns-name $label -o none
}

foreach($pip in $pips){
  $name = $pip.name
  $current = $pip.dnsSettings.domainNameLabel
  if([string]::IsNullOrEmpty($current)){
    if($name -like 'pip-agw-wus2-tst'){ Set-Label -pipName $name -prefix $Wus2LabelPrefix }
    elseif($name -like 'pip-agw-wus3-tst'){ Set-Label -pipName $name -prefix $Wus3LabelPrefix }
  } else {
    Write-Host "$name already has DNS label: $current" -ForegroundColor Green
  }
}

az network public-ip list -g $ResourceGroup -o table
