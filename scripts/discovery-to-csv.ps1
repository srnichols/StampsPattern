param(
    [string]$InFile = "discovery.json",
    [string]$OutFile = "discovery.csv"
)

if (-not (Test-Path $InFile)) { Write-Error "Input file $InFile not found"; exit 2 }

$json = Get-Content $InFile -Raw | ConvertFrom-Json

# Flatten resources to CSV with a subset of fields
$rows = $json.Resources | ForEach-Object {
    [PSCustomObject]@{
        Id = $_.Id
        Name = $_.Name
        Type = $_.Type
        Region = $_.Region
        ResourceGroup = $_.ResourceGroup
        Status = $_.Status
    }
}

$rows | Export-Csv -Path $OutFile -NoTypeInformation -Encoding UTF8
Write-Output "Wrote $($rows.Count) rows to $OutFile"
