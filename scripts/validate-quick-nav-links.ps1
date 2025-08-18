#!/usr/bin/env pwsh
# Validate Quick Navigation links in documentation files

$docFiles = Get-ChildItem -Path "docs\*.md" -Recurse | Where-Object { $_.Name -notlike "*template*" }

Write-Host "🔍 Validating Quick Navigation links..." -ForegroundColor Cyan

$issues = @()

foreach ($file in $docFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    
    # Look for Quick Navigation sections
    if ($content -match "## 🧭 Quick Navigation") {
        Write-Host "`n📋 Checking: $($file.Name)" -ForegroundColor Yellow
        
        # Extract table rows with links
        $tableMatches = [regex]::Matches($content, '\|\s*\[([^\]]+)\]\(([^)]+)\)\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|')
        
        foreach ($match in $tableMatches) {
            $linkText = $match.Groups[1].Value.Trim()
            $anchor = $match.Groups[2].Value.Trim()
            
            # Skip external links
            if ($anchor.StartsWith("http") -or $anchor.StartsWith("./")) {
                continue
            }
            
            # Convert anchor to expected header format
            $expectedHeader = $anchor -replace "^#", "" -replace "-", " "
            
            # Look for matching headers in the document
            $headerPattern = "^##+ .*" + [regex]::Escape($expectedHeader.Replace(" ", ".*")) + ".*"
            $headerMatches = [regex]::Matches($content, $headerPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline)
            
            if ($headerMatches.Count -eq 0) {
                $issue = @{
                    File = $file.Name
                    LinkText = $linkText
                    Anchor = $anchor
                    ExpectedHeader = $expectedHeader
                }
                $issues += $issue
                Write-Host "   ❌ BROKEN LINK: [$linkText]($anchor)" -ForegroundColor Red
            } else {
                Write-Host "   ✅ OK: [$linkText]($anchor)" -ForegroundColor Green
            }
        }
    }
}

if ($issues.Count -gt 0) {
    Write-Host "`n🚨 Found $($issues.Count) broken Quick Navigation links:" -ForegroundColor Red
    $issues | Format-Table -Property File, LinkText, Anchor, ExpectedHeader -AutoSize
} else {
    Write-Host "`n✅ All Quick Navigation links are valid!" -ForegroundColor Green
}
