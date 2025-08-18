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
    
    Write-Host "Setting version to $NewVersion..." -ForegroundColor Green
    
    # Note: VERSION file removed - version now tracked in CHANGELOG.md and git tags
    # Update CHANGELOG.md with new version entry if it doesn't exist
    
    # Update README.md
    $readme = Get-Content $readmeFile -Raw
    $readme = $readme -replace "(\*\*Version:\*\*\s+)[0-9]+\.[0-9]+\.[0-9]+", "`$1$NewVersion"
    $readme = $readme -replace "(!\[Version\]\(https://img\.shields\.io/badge/Version-)[0-9]+\.[0-9]+\.[0-9]+(-blue)", "`$1$NewVersion`$2"
    $readme | Set-Content $readmeFile
    
    # Update major documentation files with version footers
    $docFiles = @(
        "docs/ARCHITECTURE_GUIDE.md",
        "docs/DEPLOYMENT_GUIDE.md", 
        "docs/DEPLOYMENT_ARCHITECTURE_GUIDE.md",
        "docs/SECURITY_GUIDE.md",
        "docs/OPERATIONS_GUIDE.md"
    )
    
    foreach ($docFile in $docFiles) {
        if (Test-Path $docFile) {
            $content = Get-Content $docFile -Raw
            
            # Add or update version footer
            if ($content -match "\*\*Last Updated:\*\*.*\r?\n\*\*Pattern Version:\*\*.*") {
                # Update existing footer
                $content = $content -replace "(\*\*Last Updated:\*\*\s+)[^\r\n]*", "`$1$(Get-Date -Format 'MMMM yyyy')"
                $content = $content -replace "(\*\*Pattern Version:\*\*\s+)[^\r\n]*", "`$1v$NewVersion"
            }
            elseif ($content -match "\*Last updated:.*") {
                # Update existing simple footer and add version
                $content = $content -replace "(\*Last updated:\s+)[^\*\r\n]*", "`$1$(Get-Date -Format 'MMMM yyyy')*`r`n`r`n**Pattern Version:** v$NewVersion"
            }
            else {
                # Add new footer
                $footer = "`r`n`r`n---`r`n`r`n**Last Updated:** $(Get-Date -Format 'MMMM yyyy')  `r`n**Pattern Version:** v$NewVersion`r`n"
                $content = $content.TrimEnd() + $footer
            }
            
            $content | Set-Content $docFile
            Write-Host "Updated version in $docFile" -ForegroundColor Cyan
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
