# Quick fix for duplicate document footers
param(
    [string]$WorkspaceFolder = (Get-Location).Path
)

# Get current version
$versionScriptPath = Join-Path $WorkspaceFolder "scripts\version.ps1"
if (Test-Path $versionScriptPath) {
    $versionOutput = & $versionScriptPath -Action get
    if ($versionOutput -match "(\d+\.\d+\.\d+)") {
        $Version = $matches[1]
    } else {
        $Version = "1.3.0"
    }
} else {
    $Version = "1.3.0"
}

$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss UTC")
$nextReview = ((Get-Date).AddMonths(3)).ToString("yyyy-MM")

# New footer template
$newFooter = @"

---

**📝 Document Version Information**
- **Version**: $Version
- **Last Updated**: $timestamp  
- **Status**: Current
- **Next Review**: $nextReview
"@

# Get all markdown files in docs folder
$docFiles = Get-ChildItem -Path "docs" -Filter "*.md" -Recurse

Write-Host "Fixing document footers..." -ForegroundColor Green

foreach ($file in $docFiles) {
    try {
        $content = Get-Content $file.FullName -Raw -Encoding UTF8
        
        # Remove all existing Document Information sections
        $pattern = "---\s*\*\*📝 Document[^-]*Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)?"
        $newContent = $content -replace $pattern, ""
        
        # Remove any trailing dashes and empty lines
        $newContent = $newContent.TrimEnd()
        
        # Add the new footer
        $newContent = $newContent + $newFooter
        
        # Write back to file
        $newContent | Set-Content $file.FullName -Encoding UTF8 -NoNewline
        
        Write-Host "✅ Fixed: $($file.Name)" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ Error fixing $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Done! Fixed document footers in docs folder." -ForegroundColor Green
