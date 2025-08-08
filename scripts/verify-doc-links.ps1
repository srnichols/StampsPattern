<#######################################################################
# verify-doc-links.ps1
#
# Scans all Markdown files and validates that relative links (./ or ../)
# point to existing files. Anchors (#section) are ignored for existence.
#
# Usage:
#   pwsh -File ./scripts/verify-doc-links.ps1
#
# Exit codes:
#   0 = success, all links resolved
#   1 = failures found
#######################################################################>

param(
  [switch]$IncludeImages
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve repo root (script is under ./scripts)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Resolve-Path (Join-Path $scriptDir '..')
Set-Location $root

$mdFiles = Get-ChildItem -Path $root -Recurse -Filter *.md -File
$errors = @()

# Regex captures markdown links of the form ](./path) or ](../path)
$linkPattern = '\]\((?<path>(?:\./|\../)[^\)\s]+)\)'

foreach ($f in $mdFiles) {
  try {
    $content = Get-Content -LiteralPath $f.FullName -Raw
  } catch {
    $errors += [pscustomobject]@{ File = $f.FullName.Replace($root, '.\\'); Link = '(read error)'; Target = $_.Exception.Message }
    continue
  }

  # Skip image links if not requested
  $text = if ($IncludeImages) { $content } else { $content -replace '!\[', '[' }

  if ([string]::IsNullOrEmpty($text)) { continue }

  $linkMatches = [regex]::Matches($text, $linkPattern)
  foreach ($m in $linkMatches) {
    $link = $m.Groups['path'].Value
    # strip anchors
    $relNoAnchor = $link.Split('#')[0]

    if ($relNoAnchor.StartsWith('./')) {
      $target = Join-Path (Split-Path $f.FullName -Parent) $relNoAnchor.Substring(2)
    } elseif ($relNoAnchor.StartsWith('../')) {
      $target = Join-Path (Split-Path $f.FullName -Parent) $relNoAnchor
    } else {
      continue
    }

    $exists = Test-Path -LiteralPath $target
    if (-not $exists) {
      $errors += [pscustomobject]@{
        File   = $f.FullName.Replace($root, '.\\')
        Link   = $link
        Target = $target.Replace($root, '.\\')
      }
    }
  }
}

if ($errors.Count -gt 0) {
  Write-Host "Broken relative links detected:`n" -ForegroundColor Red
  $errors | Sort-Object File, Link | Format-Table -AutoSize | Out-String | Write-Host
  exit 1
} else {
  Write-Host 'Relative link check passed.' -ForegroundColor Green
}
