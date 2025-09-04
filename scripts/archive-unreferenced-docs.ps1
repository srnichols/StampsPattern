# Archive unreferenced markdown files in docs/ root into docs/obsolete/
$doc = Get-Content docs/DOCS.md -Raw
$matches = [regex]::Matches($doc,'\(\./([^\)]+\.md)\)')
$links = @()
foreach ($m in $matches) { $links += (Split-Path $m.Groups[1].Value -Leaf) }
$links = $links | Select-Object -Unique
Write-Output 'Referenced files in DOCS.md:'
$links | ForEach-Object { Write-Output " - $_" }
$docsRoot = (Resolve-Path docs).Path
$files = Get-ChildItem -Path $docsRoot -File -Filter *.md | Where-Object { $_.DirectoryName -eq $docsRoot } | Select-Object -ExpandProperty Name
Write-Output 'Top-level docs files:'
$files | ForEach-Object { Write-Output " - $_" }
$candidates = $files | Where-Object { ($_ -ne 'DOCS.md') -and ($_ -ne 'REPOSITORY_MAP.md') -and ($links -notcontains $_) }
if ($candidates.Count -eq 0) { Write-Output 'No unreferenced docs found in docs/ root.'; exit 0 }
Write-Output 'Unreferenced docs to archive:'
$candidates | ForEach-Object { Write-Output " - $_" }
mkdir -Force docs/obsolete
foreach ($f in $candidates) { git mv "docs/$f" "docs/obsolete/$f"; Write-Output "Moved: $f" }
git commit -m 'chore(docs): archive unreferenced docs'
git push origin main
