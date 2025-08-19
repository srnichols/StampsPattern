#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Version management script for Azure Stamps Pattern
.DESCRIPTION
    Manages version numbers through CHANGELOG.md and git tags instead of a VERSION file.
    Updates version entries in CHANGELOG.md and creates git tags for releases.
.PARAMETER Action
    Action to perform: 'bump' (increment version), 'set' (set specific version), or 'get' (show current version)
.PARAMETER Type
    Version increment type: 'major', 'minor', or 'patch' (default: patch)
.PARAMETER Version
    Specific version to set when using 'set' action (e.g., "1.3.0")
.PARAMETER Message
    Release message for the changelog entry
.EXAMPLE
    .\scripts\version.ps1 -Action bump -Type minor -Message "Added new feature"
    .\scripts\version.ps1 -Action set -Version "2.0.0" -Message "Major release"
    .\scripts\version.ps1 -Action get
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('bump', 'set', 'get')]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('major', 'minor', 'patch')]
    [string]$Type = 'patch',
    
    [Parameter(Mandatory=$false)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [string]$Message
)

# Since VERSION file was removed, version is now managed in CHANGELOG.md
# This script now reads version from CHANGELOG.md and manages releases through git tags
$changelogFile = "CHANGELOG.md"
$readmeFile = "README.md"

function Get-CurrentVersion {
    if (Test-Path $changelogFile) {
        # Extract version from first ## [version] line in CHANGELOG.md
        $content = Get-Content $changelogFile
        foreach ($line in $content) {
            if ($line -match '## \[(\d+\.\d+\.\d+)\]') {
                return $matches[1]
            }
        }
    }
    return "1.0.0"
}

function Set-Version {
    param([string]$NewVersion)
    
    <#
    .SYNOPSIS
        Updates version information across all documentation files with clean footer replacement
    .DESCRIPTION
        This function uses a surgical string-indexing approach instead of regex to prevent:
        1. Footer duplication (previous regex was non-greedy and left partial footers)
        2. UTF-8 corruption (PowerShell regex operations corrupted emojis like 🔌 → ðŸ"Œ)
        
        The approach: Find exact footer boundaries, extract clean sections, replace precisely.
        This ensures only the footer section is modified while preserving all other content.
    #>
    
    Write-Host "Setting version to $NewVersion..." -ForegroundColor Green
    
    # Note: VERSION file removed - version now tracked in CHANGELOG.md and git tags
    # Update CHANGELOG.md with new version entry if it doesn't exist
    
    # Update README.md
    $readme = Get-Content $readmeFile -Raw
    $readme = $readme -replace "(\*\*Version:\*\*\s+)[0-9]+\.[0-9]+\.[0-9]+", "`$1$NewVersion"
    $readme = $readme -replace "(!\[Version\]\(https://img\.shields\.io/badge/Version-)[0-9]+\.[0-9]+\.[0-9]+(-blue)", "`$1$NewVersion`$2"
    $readme | Set-Content $readmeFile
    
    # Update all documentation files with version footers
    $docFiles = @(
        "docs/ARCHITECTURE_GUIDE.md",
        "docs/AUTH_CI_STRATEGY.md", 
        "docs/Azure_Stamps_Pattern_Analysis_WhitePaper.md",
        "docs/Azure_Stamp_Pattern_Sample_App_Plan.md",
        "docs/CAF_WAF_COMPLIANCE_ANALYSIS.md",
        "docs/CAPABILITIES_MATRIX.md",
        "docs/COST_OPTIMIZATION_GUIDE.md",
        "docs/DATA_STRATEGY_GUIDE.md",
        "docs/DEPLOYMENT_ARCHITECTURE_GUIDE.md",
        "docs/DEPLOYMENT_GUIDE.md",
        "docs/DEVELOPER_QUICKSTART.md",
        "docs/DEVELOPER_SECURITY_GUIDE.md",
        "docs/DOCS.md",
        "docs/GLOSSARY.md",
        "docs/KNOWN_ISSUES.md",
        "docs/LANDING_ZONES_GUIDE.md",
        "docs/LIVE_DATA_PATH.md",
        "docs/MANAGEMENT_PORTAL_USER_GUIDE.md",
        "docs/mermaid-template.md",
        "docs/NAMING_CONVENTIONS_GUIDE.md",
        "docs/OPERATIONS_GUIDE.md",
        "docs/PARAMETERIZATION_GUIDE.md",
        "docs/RBAC_CHEATSHEET.md",
        "docs/REPOSITORY_MAP.md",
        "docs/SECRETS_AND_CONFIG.md",
        "docs/SECURITY_GUIDE.md",
        "docs/TROUBLESHOOTING_PLAYBOOKS.md"
    )
    
    foreach ($docFile in $docFiles) {
        if (Test-Path $docFile) {
            $content = Get-Content $docFile -Raw
            $updated = $false
            
            # Remove duplicate "Last updated:" entries that conflict with formal footer
            # These sometimes appear from manual edits and need cleanup
            $content = $content -replace "_Last updated:.*?_\s*\r?\n", ""
            $content = $content -replace "Last updated:.*?\r?\n", ""
            
            # Standard footer format to match README.md
            $currentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $standardFooter = @"
**📝 Document Version Information**
- **Version**: $NewVersion
- **Last Updated**: $currentDate UTC  
- **Status**: Current
- **Next Review**: 2025-11
"@

            # FOOTER REPLACEMENT LOGIC - Using string indexing instead of regex
            # Why: Previous regex approach caused two major issues:
            # 1. Footer duplication: Non-greedy regex (.*?) didn't capture complete multi-line footers
            # 2. Content corruption: PowerShell regex operations corrupted UTF-8 emojis (🔌 became ðŸ"Œ)
            # 
            # Solution: Use precise string indexing to find and replace exact footer boundaries
            # This approach is surgical - only touches the footer section, preserves all other content
            
            # Check if document already has the version footer
            # Look for the exact footer start marker (this is our anchor point)
            $footerMarker = "**📝 Document Version Information**"
            $footerIndex = $content.IndexOf($footerMarker)
            
            if ($footerIndex -ge 0) {
                # Footer exists - we need to replace it completely to avoid duplication
                # Strategy: Find footer boundaries, extract before/after sections, insert clean footer
                
                # Find the end of the existing footer section
                # Footer typically ends at double newline (document section break) or end of file
                $remainingContent = $content.Substring($footerIndex)
                $footerEndIndex = $remainingContent.IndexOf("`r`n`r`n")
                
                if ($footerEndIndex -eq -1) {
                    # Footer goes to end of file - replace everything from footer marker onward
                    $beforeFooter = $content.Substring(0, $footerIndex).TrimEnd()
                    $content = $beforeFooter + "`r`n`r`n" + $standardFooter + "`r`n"
                } else {
                    # Footer has content after it - preserve the content after the footer
                    $beforeFooter = $content.Substring(0, $footerIndex).TrimEnd()
                    $afterFooter = $content.Substring($footerIndex + $footerEndIndex)
                    $content = $beforeFooter + "`r`n`r`n" + $standardFooter + $afterFooter
                }
                $updated = $true
            }
            else {
                # No existing footer found - add new footer at the end
                # Format: ensure proper spacing with document separator and clean ending
                $content = $content.TrimEnd() + "`r`n`r`n---`r`n`r`n" + $standardFooter + "`r`n"
                $updated = $true
            }
            
            if ($updated) {
                # Write file with -NoNewline to preserve exact formatting
                # Note: PowerShell Set-Content preserves original encoding when using -NoNewline
                # This prevents UTF-8 emoji corruption that occurred with previous regex approach
                $content | Set-Content $docFile -NoNewline
                Write-Host "Updated version footer in $docFile" -ForegroundColor Cyan
            }
        }
    }
    
    Write-Host "Version information updated to $NewVersion in CHANGELOG.md and documentation" -ForegroundColor Green
}

function Step-Version {
    param([string]$BumpType)
    
    $currentVersion = Get-CurrentVersion
    $versionParts = $currentVersion.Split('.')
    
    $major = [int]$versionParts[0]
    $minor = [int]$versionParts[1]
    $patch = [int]$versionParts[2]
    
    switch ($BumpType) {
        'major' {
            $major++
            $minor = 0
            $patch = 0
        }
        'minor' {
            $minor++
            $patch = 0
        }
        'patch' {
            $patch++
        }
    }
    
    $newVersion = "$major.$minor.$patch"
    return $newVersion
}

function Update-Changelog {
    param([string]$NewVersion, [string]$ReleaseMessage)
    
    if (-not (Test-Path $changelogFile)) {
        Write-Warning "Changelog file not found. Skipping changelog update."
        return
    }
    
    $currentDate = Get-Date -Format "yyyy-MM-dd"
    $changelog = Get-Content $changelogFile -Raw
    
    # Find the position after the first ## [Unreleased] or ## [version] section
    $insertPosition = $changelog.IndexOf("## [")
    if ($insertPosition -eq -1) {
        Write-Warning "Could not find changelog insertion point. Please update manually."
        return
    }
    
    $newEntry = @"

## [$NewVersion] - $currentDate

### Added
- $ReleaseMessage

"@
    
    $changelog = $changelog.Insert($insertPosition, $newEntry)
    $changelog | Set-Content $changelogFile
    
    Write-Host "Changelog updated with version $NewVersion" -ForegroundColor Green
}

# Main execution
switch ($Action) {
    'get' {
        $currentVersion = Get-CurrentVersion
        Write-Host "Current version: $currentVersion" -ForegroundColor Cyan
    }
    
    'bump' {
        if (-not $Message) {
            $Message = "Version increment ($Type)"
        }
        
        $oldVersion = Get-CurrentVersion
        $newVersion = Step-Version -BumpType $Type
        Set-Version -NewVersion $newVersion
        Update-Changelog -NewVersion $newVersion -ReleaseMessage $Message
        
        Write-Host "Version incremented from $oldVersion to $newVersion" -ForegroundColor Green
        Write-Host "Don't forget to:" -ForegroundColor Yellow
        Write-Host "  1. Review and edit CHANGELOG.md with specific changes" -ForegroundColor Yellow
        Write-Host "  2. Commit changes: git add . && git commit -m 'Bump version to $newVersion'" -ForegroundColor Yellow
        Write-Host "  3. Create git tag: git tag v$newVersion" -ForegroundColor Yellow
        Write-Host "  4. Push changes: git push && git push --tags" -ForegroundColor Yellow
    }
    
    'set' {
        if (-not $Version) {
            Write-Error "Version parameter is required when using 'set' action"
            exit 1
        }
        
        if (-not ($Version -match '^\d+\.\d+\.\d+$')) {
            Write-Error "Version must be in format X.Y.Z (e.g., 1.2.3)"
            exit 1
        }
        
        if (-not $Message) {
            $Message = "Version set to $Version"
        }
        
        Set-Version -NewVersion $Version
        Update-Changelog -NewVersion $Version -ReleaseMessage $Message
        
        Write-Host "Version set to $Version" -ForegroundColor Green
        Write-Host "Don't forget to commit and tag the changes!" -ForegroundColor Yellow
    }
}
