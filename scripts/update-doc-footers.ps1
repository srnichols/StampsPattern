# Update Documentation Footers
# This script updates version footers across all documentation files

param(
    [string]$Version,
    [string]$WorkspaceFolder = (Get-Location).Path
)

# Get current version if not provided
if (-not $Version) {
    $versionScriptPath = Join-Path $WorkspaceFolder "scripts\version.ps1"
    if (Test-Path $versionScriptPath) {
        $versionOutput = & $versionScriptPath -Action get
        # Extract just the version number from output like "Current version: 1.3.0"
        if ($versionOutput -match "(\d+\.\d+\.\d+)") {
            $Version = $matches[1]
        } else {
            $Version = "1.3.0"
        }
        Write-Host "Current version: $Version"
    } else {
        $Version = "1.3.0"
        Write-Host "Using default version: $Version"
    }
}

# Generate timestamp
$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss UTC")
$nextReview = ((Get-Date).AddMonths(3)).ToString("yyyy-MM")

# Define the standardized footer template
$footerTemplate = @"

---

**📝 Document Information**
- **Version**: $Version
- **Last Updated**: $timestamp  
- **Status**: Current
- **Next Review**: $nextReview

---

*Part of the [Azure Stamps Pattern](../README.md) documentation suite*
"@

$readmeFooterTemplate = @"

---

**📝 Document Information**
- **Version**: $Version
- **Last Updated**: $timestamp  
- **Status**: Current
- **Next Review**: $nextReview

---

*Part of the [Azure Stamps Pattern](README.md) documentation suite*
"@

# Define files to update with their footer patterns
$filesToUpdate = @(
    @{
        Path = "README.md"
        OldPattern = "---\s*\*\*📝 Document Information\*\*.*?documentation suite\*"
        NewFooter = $readmeFooterTemplate
        Description = "Main README"
    }
    @{
        Path = "docs\DOCS.md"
        OldPattern = "---\s*\*\*📝 Document Information\*\*.*?documentation suite\*"
        NewFooter = $footerTemplate
        Description = "Documentation Hub"
    }
    @{
        Path = "docs\ARCHITECTURE_GUIDE.md"
        OldPattern = "---\s*\*\*📝 Document Information\*\*.*?documentation suite\*"
        NewFooter = $footerTemplate
        Description = "Architecture Guide"
    }
    @{
        Path = "docs\DEPLOYMENT_GUIDE.md"
        OldPattern = "---\s*\*\*📝 Document Information\*\*.*?documentation suite\*"
        NewFooter = $footerTemplate
        Description = "Deployment Guide"
    }
    @{
        Path = "docs\SECURITY_GUIDE.md"
        OldPattern = "---\s*\*\*📝 Document Information\*\*.*?documentation suite\*"
        NewFooter = $footerTemplate
        Description = "Security Guide"
    }
    @{
        Path = "docs\OPERATIONS_GUIDE.md"
        OldPattern = "---\s*\*\*📝 Document Information\*\*.*?documentation suite\*"
        NewFooter = $footerTemplate
        Description = "Operations Guide"
    }
    @{
        Path = "docs\MANAGEMENT_PORTAL_USER_GUIDE.md"
        OldPattern = "---\s*\*\*📝 Document Information\*\*.*?documentation suite\*"
        NewFooter = $footerTemplate
        Description = "Management Portal User Guide"
    }
    @{
        Path = "docs\CAF_WAF_COMPLIANCE_ANALYSIS.md"
        OldPattern = "---\s*\*\*📝 Document Information\*\*.*?documentation suite\*"
        NewFooter = $footerTemplate
        Description = "CAF/WAF Compliance Analysis"
    }
    @{
        Path = "docs\DEVELOPER_QUICKSTART.md"
        OldPattern = "---\s*\*\*📝 Document Information\*\*.*?documentation suite\*"
        NewFooter = $footerTemplate
        Description = "Developer Quickstart"
    }
    @{
        Path = "docs\KNOWN_ISSUES.md"
        OldPattern = "---\s*\*\*📝 Document Information\*\*.*?documentation suite\*"
        NewFooter = $footerTemplate
        Description = "Known Issues"
    }
)

$updatedCount = 0
$errorCount = 0

Write-Host "Updating documentation footers..." -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Cyan
Write-Host "Timestamp: $timestamp" -ForegroundColor Cyan
Write-Host ""

foreach ($file in $filesToUpdate) {
    $fullPath = Join-Path $WorkspaceFolder $file.Path
    
    if (-not (Test-Path $fullPath)) {
        Write-Host "⚠️  File not found: $($file.Path)" -ForegroundColor Yellow
        continue
    }
    
    try {
        $content = Get-Content $fullPath -Raw -Encoding UTF8
        
        # Check if footer already exists
        if ($content -match $file.OldPattern) {
            # Replace existing footer
            $newContent = $content -replace $file.OldPattern, $file.NewFooter.Trim(), "Singleline"
            Write-Host "✅ Updated existing footer: $($file.Description)" -ForegroundColor Green
        } else {
            # Add new footer
            $newContent = $content.TrimEnd() + $file.NewFooter
            Write-Host "➕ Added new footer: $($file.Description)" -ForegroundColor Blue
        }
        
        # Write updated content
        $newContent | Set-Content $fullPath -Encoding UTF8 -NoNewline
        $updatedCount++
        
    } catch {
        Write-Host "❌ Error updating $($file.Path): $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
}

Write-Host ""
Write-Host "Summary:" -ForegroundColor Green
Write-Host "✅ Updated: $updatedCount files" -ForegroundColor Green
if ($errorCount -gt 0) {
    Write-Host "❌ Errors: $errorCount files" -ForegroundColor Red
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Review the changes: git diff"
Write-Host "2. Commit the updates: git add . && git commit -m 'docs: update version footers to v$Version'"
Write-Host "3. Push to remote: git push"
