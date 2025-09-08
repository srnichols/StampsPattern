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

**📝 Document Version Information**
- **Version**: $Version
- **Last Updated**: $timestamp  
- **Status**: Current
- **Next Review**: $nextReview
"@

$readmeFooterTemplate = @"

---

**📝 Document Version Information**
- **Version**: $Version
- **Last Updated**: $timestamp  
- **Status**: Current
- **Next Review**: $nextReview
"@

# Define files to update with their footer patterns
$filesToUpdate = @(
    @{ Path = "README.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $readmeFooterTemplate; Description = "Main README" },
    @{ Path = "docs\DOCS.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Documentation Hub" },
    @{ Path = "docs\ARCHITECTURE_GUIDE.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Architecture Guide" },
    @{ Path = "docs\DEPLOYMENT_GUIDE.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Deployment Guide" },
    @{ Path = "docs\SECURITY_GUIDE.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Security Guide" },
    @{ Path = "docs\OPERATIONS_GUIDE.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Operations Guide" },
    @{ Path = "docs\MANAGEMENT_PORTAL_USER_GUIDE.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Management Portal User Guide" },
    @{ Path = "docs\CAF_WAF_COMPLIANCE_ANALYSIS.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "CAF/WAF Compliance Analysis" },
    @{ Path = "docs\DEVELOPER_QUICKSTART.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Developer Quickstart" },
    @{ Path = "docs\KNOWN_ISSUES.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Known Issues" },
    @{ Path = "docs\LANDING_ZONES_GUIDE.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Landing Zones Guide" },
    @{ Path = "docs\NAMING_CONVENTIONS_GUIDE.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Naming Conventions Guide" },
    @{ Path = "docs\PARAMETERIZATION_GUIDE.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Parameterization Guide" },
    @{ Path = "docs\GLOSSARY.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Glossary" },
    @{ Path = "docs\Azure_Stamps_Pattern_Analysis_WhitePaper.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Azure Stamps Pattern Analysis WhitePaper" },
    @{ Path = "docs\DEPLOYMENT_ARCHITECTURE_GUIDE.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Deployment Architecture Guide" },
    @{ Path = "docs\DATA_STRATEGY_GUIDE.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Data Strategy Guide" },
    @{ Path = "docs\DEVELOPER_SECURITY_GUIDE.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Developer Security Guide" },
    @{ Path = "docs\LIVE_DATA_PATH.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Live Data Path" },
    @{ Path = "docs\COST_OPTIMIZATION_GUIDE.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Cost Optimization Guide" },
    @{ Path = "docs\SECRETS_AND_CONFIG.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Secrets and Configuration" },
    @{ Path = "docs\TROUBLESHOOTING_PLAYBOOKS.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Troubleshooting Playbooks" },
    @{ Path = "docs\PROBLEM_STATEMENT.md"; OldPattern = "---\s*\*\*📝 Document (Version )?Information\*\*.*?(\*Part of the.*?documentation suite\*\s*)*$"; NewFooter = $footerTemplate; Description = "Problem Statement" }
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
            # Replace existing footer(s) - handle multiple footers
            $newContent = $content -replace $file.OldPattern, $file.NewFooter.Trim()
            Write-Host "✅ Updated existing footer: $($file.Description)" -ForegroundColor Green
        } else {
            # Check for any Document Information sections to remove duplicates
            $newContent = $content -replace "---\s*\*\*📝 Document.*?Next Review.*?\d{4}-\d{2}[^-]*?---[^*]*\*Part of the.*?documentation suite\*", ""
            $newContent = $newContent -replace "---\s*\*\*📝 Document.*?Next Review.*?\d{4}-\d{2}", ""
            # Add new footer
            $newContent = $newContent.TrimEnd() + $file.NewFooter
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
