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
  [switch]$IncludeImages,
  [switch]$CheckExternal,
  [int]$ExternalTimeoutSec = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve repo root (script is under ./scripts)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Resolve-Path (Join-Path $scriptDir '..')
Set-Location $root

$mdFiles = Get-ChildItem -Path $root -Recurse -Filter *.md -File
$errors = @()
$externalErrors = @()

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

  # External link validation (Markdown link syntax only) when enabled
  if ($CheckExternal) {
    $externalPattern = '\]\((?<url>https?://[^\)\s]+)\)'
    $extMatches = [regex]::Matches($text, $externalPattern)
    if ($extMatches.Count -gt 0) {
      # Deduplicate URLs per file to minimize requests
      $urls = $extMatches | ForEach-Object { $_.Groups['url'].Value } | Sort-Object -Unique

      # Use HttpClient for efficient HEAD/GET without downloading bodies
      $handler = [System.Net.Http.HttpClientHandler]::new()
      $client = [System.Net.Http.HttpClient]::new($handler)
      $client.Timeout = [TimeSpan]::FromSeconds([Math]::Max(1, $ExternalTimeoutSec))

      foreach ($u in $urls) {
        try {
          $req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, $u)
          $resp = $client.Send($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
          $status = [int]$resp.StatusCode
          $resp.Dispose()

          # Accept: 2xx, 3xx, 401, 403, 429
          if (!($status -ge 200 -and $status -lt 400) -and $status -ne 401 -and $status -ne 403 -and $status -ne 429) {
            # Retry with GET if HEAD not allowed or other non-success
            $req2 = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $u)
            $resp2 = $client.Send($req2, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
            $status2 = [int]$resp2.StatusCode
            $resp2.Dispose()

            if (!($status2 -ge 200 -and $status2 -lt 400) -and $status2 -ne 401 -and $status2 -ne 403 -and $status2 -ne 429) {
              $externalErrors += [pscustomobject]@{
                File   = $f.FullName.Replace($root, '.\\')
                Link   = $u
                Status = $status2
              }
            }
          }
        } catch {
          $externalErrors += [pscustomobject]@{
            File   = $f.FullName.Replace($root, '.\\')
            Link   = $u
            Status = $_.Exception.GetType().Name
          }
        }
      }

      $client.Dispose()
      $handler.Dispose()
    }
  }
}

if ($errors.Count -gt 0 -or $externalErrors.Count -gt 0) {
  $host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size (4096, $host.UI.RawUI.BufferSize.Height)
  Write-Host "Broken relative links detected:`n" -ForegroundColor Red
  ($errors | Sort-Object File, Link | Format-Table -AutoSize | Out-String -Width 4096) | Write-Host
  if ($CheckExternal) {
    Write-Host "Broken external links detected:`n" -ForegroundColor Red
    ($externalErrors | Sort-Object File, Link | Format-Table -Property File,Link,Status -AutoSize | Out-String -Width 4096) | Write-Host
  }
  try {
    $reportPath = Join-Path $root 'link-check-report.csv'
    $combined = @()
    if ($errors.Count -gt 0) { $combined += $errors | Select-Object @{N='Type';E={'Relative'}}, File, Link, @{N='Status';E={'NotFound'}} }
    if ($externalErrors.Count -gt 0) { $combined += $externalErrors | Select-Object @{N='Type';E={'External'}}, File, Link, Status }
    if ($combined.Count -gt 0) {
      $combined | Export-Csv -NoTypeInformation -Path $reportPath -Encoding UTF8
      Write-Host "Saved detailed report: $reportPath" -ForegroundColor Yellow
    }
  } catch {
    Write-Host "Failed to write CSV report: $($_.Exception.Message)" -ForegroundColor Yellow
  }
  exit 1
} else {
  if ($CheckExternal) {
    Write-Host 'Relative + external link check passed.' -ForegroundColor Green
  } else {
    Write-Host 'Relative link check passed.' -ForegroundColor Green
  }
}
