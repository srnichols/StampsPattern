#!/usr/bin/env pwsh
#
# Fix documentation formatting issues
#

param(
    [string]$DocsPath = "docs",
    [switch]$WhatIf
)

$fixedFiles = 0
$totalFiles = 0

function Remove-DuplicateFooters {
    param([string]$FilePath)
    
    $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
    $originalContent = $content
    
    # Remove duplicate "Part of the Azure Stamps Pattern documentation suite" sections
    $content = $content -replace '(?s)\r?\n---\r?\n\r?\n\*Part of the \[Azure Stamps Pattern\]\(\.\./README\.md\) documentation suite\*\r?\n\r?\n- \*\*Version\*\*:.*?\r?\n- \*\*Last Updated\*\*:.*?\r?\n- \*\*Status\*\*:.*?\r?\n- \*\*Next Review\*\*:.*?\r?\n', ''
    
    # Remove old pattern version markers
    $content = $content -replace '\r?\n\*\*Pattern Version:\*\* v\d+\.\d+\.\d+\*', ''
    
    # Clean up multiple consecutive blank lines
    $content = $content -replace '\r?\n\r?\n\r?\n+', "`r`n`r`n"
    
    # Ensure proper line endings
    $content = $content -replace '\r?\n', "`r`n"
    
    if ($content -ne $originalContent) {
        return $true
    }
    return $false
}

# Get all markdown files
$markdownFiles = Get-ChildItem -Path $DocsPath -Recurse -Filter "*.md"

Write-Host "Fixing documentation formatting issues..." -ForegroundColor Cyan

foreach ($file in $markdownFiles) {
    $totalFiles++
    $relativePath = $file.FullName -replace [regex]::Escape((Get-Location).Path + "\"), ""
    
    try {
        if (Remove-DuplicateFooters -FilePath $file.FullName) {
            $fixedFiles++
            if ($WhatIf) {
                Write-Host "Would fix: $relativePath" -ForegroundColor Yellow
            } else {
                $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
                
                # Apply the fixes
                $content = $content -replace '(?s)\r?\n---\r?\n\r?\n\*Part of the \[Azure Stamps Pattern\]\(\.\./README\.md\) documentation suite\*\r?\n\r?\n- \*\*Version\*\*:.*?\r?\n- \*\*Last Updated\*\*:.*?\r?\n- \*\*Status\*\*:.*?\r?\n- \*\*Next Review\*\*:.*?\r?\n', ''
                $content = $content -replace '\r?\n\*\*Pattern Version:\*\* v\d+\.\d+\.\d+\*', ''
                $content = $content -replace '\r?\n\r?\n\r?\n+', "`r`n`r`n"
                $content = $content -replace '\r?\n', "`r`n"
                
                Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
                Write-Host "Fixed: $relativePath" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "Error processing ${relativePath}: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "Total files processed: $totalFiles" -ForegroundColor White
Write-Host "Files fixed: $fixedFiles" -ForegroundColor $(if ($fixedFiles -gt 0) { "Green" } else { "White" })

if ($WhatIf) {
    Write-Host "Run without -WhatIf to apply fixes" -ForegroundColor Yellow
} elseif ($fixedFiles -gt 0) {
    Write-Host "Documentation formatting issues have been fixed!" -ForegroundColor Green
}
