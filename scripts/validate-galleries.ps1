<#
Validate galleries script - checks that SCREENSHOTS.md files reference images that exist.
Run locally from repo root:
  pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/validate-galleries.ps1
#>

$errors = @()

Get-ChildItem -Path . -Recurse -Filter SCREENSHOTS.md | ForEach-Object {
    $md = $_.FullName
    Write-Output "Checking: $md"
    $content = Get-Content $md -Raw
    # remove fenced code blocks so example markup isn't validated
    $content = [regex]::Replace($content, '```[\s\S]*?```', '', 'Singleline')
    # find image references: ![alt](path) or <img src="path"
    $pattern1 = '!\[[^\]]*\]\(([^)]+)\)'
    $pattern2 = '<img[^>]*src\s*=\s*"([^"]+)"'
    foreach ($m in [regex]::Matches($content,$pattern1)){
        $path = $m.Groups[1].Value
        # skip URLs
        if ($path -match '^(https?:)?//') { continue }
        $p = Join-Path (Split-Path $md -Parent) $path
        if (-not (Test-Path $p)){
            # try relative to repo root as some docs include repo-root relative paths
            $repoRoot = (Resolve-Path .).Path
            $p2 = Join-Path $repoRoot $path
            if (-not (Test-Path $p2)){
                $errors += "Missing image referenced in $($md): $($path)"
            }
        }
    }
    foreach ($m in [regex]::Matches($content,$pattern2)){
        $path = $m.Groups[1].Value
        if ($path -match '^(https?:)?//') { continue }
        $p = Join-Path (Split-Path $md -Parent) $path
        if (-not (Test-Path $p)){
            $repoRoot = (Resolve-Path .).Path
            $p2 = Join-Path $repoRoot $path
            if (-not (Test-Path $p2)){
                $errors += "Missing image referenced in $($md): $($path)"
            }
        }
    }
}

if ($errors.Count -gt 0){
    Write-Error "Validation failed - missing images:`n$($errors -join "`n")"
    exit 1
}
else{
    Write-Output "All gallery images are present."
}
