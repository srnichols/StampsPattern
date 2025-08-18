#!/usr/bin/env pwsh
#
# Scan all documentation files for formatting issues
#

param(
    [string]$DocsPath = "docs",
    [switch]$Fix,
    [switch]$Verbose
)

# Initialize results
$issues = @()
$totalFiles = 0
$filesWithIssues = 0

# Colors for output
$ErrorColor = "Red"
$WarningColor = "Yellow" 
$SuccessColor = "Green"
$InfoColor = "Cyan"

function Write-Status {
    param($Message, $Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-DocumentFile {
    param([string]$FilePath)
    
    $script:totalFiles++
    $fileIssues = @()
    $relativePath = $FilePath -replace [regex]::Escape((Get-Location).Path + "\"), ""
    
    Write-Status "Scanning: $relativePath" $InfoColor
    
    try {
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
        $lines = Get-Content -Path $FilePath -Encoding UTF8
        
        # Check for multiple version footers
        $footerMatches = [regex]::Matches($content, '(?m)^-\s+\*\*Version\*\*:|^-\s+\*\*Last Updated\*\*:|^\*\*📝 Document Version Information\*\*')
        if ($footerMatches.Count -gt 4) {
            $fileIssues += "Multiple version footers detected ($($footerMatches.Count) footer lines)"
        }
        
        # Check for malformed mermaid diagrams
        $mermaidBlocks = [regex]::Matches($content, '(?s)```mermaid.*?```')
        foreach ($block in $mermaidBlocks) {
            $blockContent = $block.Value
            if ($blockContent -match '```\s*```') {
                $fileIssues += "Malformed mermaid diagram: extra backticks detected"
            }
            $backtickCount = ($blockContent | Select-String '```' -AllMatches).Matches.Count
            if ($backtickCount % 2 -ne 0) {
                $fileIssues += "Malformed mermaid diagram: unclosed code block"
            }
        }
        
        # Check for broken code blocks
        $codeBlocks = [regex]::Matches($content, '(?m)^```')
        if ($codeBlocks.Count % 2 -ne 0) {
            $fileIssues += "Mismatched code block markers (odd number of ```)"
        }
        
        # Check for old footer patterns
        if ($content -match '\*Part of the.*Azure Stamps Pattern.*documentation suite\*') {
            $fileIssues += "Old footer pattern detected"
        }
        
        # Check for pattern version markers
        $patternVersions = [regex]::Matches($content, '\*\*Pattern Version:\*\*')
        if ($patternVersions.Count -gt 0) {
            $fileIssues += "Old pattern version markers detected ($($patternVersions.Count) instances)"
        }
        
        # Check for empty version numbers
        if ($content -match '\*\*Version\*\*:\s*$' -or $content -match '- \*\*Version\*\*:\s*$') {
            $fileIssues += "Empty version number detected"
        }
        
        if ($fileIssues.Count -gt 0) {
            $script:filesWithIssues++
            $script:issues += [PSCustomObject]@{
                File = $relativePath
                Issues = $fileIssues
            }
            
            Write-Status "  ❌ Found $($fileIssues.Count) issue(s)" $WarningColor
            if ($Verbose) {
                foreach ($issue in $fileIssues) {
                    Write-Status "    - $issue" $ErrorColor
                }
            }
        } else {
            Write-Status "  ✅ No issues found" $SuccessColor
        }
        
    } catch {
        Write-Status "  ❌ Error scanning file: $($_.Exception.Message)" $ErrorColor
        $script:issues += [PSCustomObject]@{
            File = $relativePath
            Issues = @("Error reading file: $($_.Exception.Message)")
        }
        $script:filesWithIssues++
    }
}

# Main execution
Write-Status "🔍 Scanning documentation files for formatting issues..." $InfoColor
Write-Status ""

# Get all markdown files in docs folder
$markdownFiles = Get-ChildItem -Path $DocsPath -Recurse -Filter "*.md" | Sort-Object FullName

foreach ($file in $markdownFiles) {
    Test-DocumentFile -FilePath $file.FullName
}

# Summary report
Write-Status ""
Write-Status "📊 SCAN SUMMARY" $InfoColor
Write-Status "===============" $InfoColor
Write-Status "Total files scanned: $totalFiles" $InfoColor
Write-Status "Files with issues: $filesWithIssues" $(if ($filesWithIssues -gt 0) { $WarningColor } else { $SuccessColor })
Write-Status "Files without issues: $($totalFiles - $filesWithIssues)" $SuccessColor

if ($issues.Count -gt 0) {
    Write-Status ""
    Write-Status "🚨 DETAILED ISSUES REPORT" $ErrorColor
    Write-Status "=========================" $ErrorColor
    
    foreach ($fileIssue in $issues) {
        Write-Status ""
        Write-Status "📄 File: $($fileIssue.File)" $WarningColor
        foreach ($issue in $fileIssue.Issues) {
            Write-Status "   - $issue" $ErrorColor
        }
    }
    
    if ($Fix) {
        Write-Status ""
        Write-Status "🔧 AUTO-FIX MODE ENABLED" $InfoColor
        Write-Status "This would automatically fix common issues..." $InfoColor
        Write-Status "(Auto-fix functionality would be implemented here)" $WarningColor
    } else {
        Write-Status ""
        Write-Status "💡 To automatically fix common issues, run with -Fix parameter" $InfoColor
    }
} else {
    Write-Status ""
    Write-Status "🎉 All documentation files are properly formatted!" $SuccessColor
}

Write-Status ""
Write-Status "Scan completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" $InfoColor
