#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Intelligent Quick Navigation fixer that matches links to actual section headers
.DESCRIPTION
    Reads actual section headers from files and correctly matches Quick Navigation links
    to the proper GitHub-generated anchor IDs.
#>

param(
    [switch]$DryRun
)

function Convert-ToGitHubAnchor {
    param([string]$text)
    
    # GitHub anchor generation rules:
    # 1. Remove emojis and special Unicode characters
    # 2. Convert to lowercase  
    # 3. Replace spaces with hyphens
    # 4. Remove most special characters except hyphens
    # 5. Remove leading/trailing hyphens
    
    $anchor = $text
    
    # Remove markdown formatting
    $anchor = $anchor -replace '\*\*', ''
    $anchor = $anchor -replace '\*', ''
    $anchor = $anchor -replace '`', ''
    
    # Remove emojis (Unicode ranges for emojis)
    $anchor = $anchor -replace '[\u{1F300}-\u{1F9FF}]', ''
    $anchor = $anchor -replace '[\u{2600}-\u{26FF}]', ''
    $anchor = $anchor -replace '[\u{2700}-\u{27BF}]', ''
    $anchor = $anchor -replace '[\u{1F600}-\u{1F64F}]', ''
    $anchor = $anchor -replace '[\u{1F680}-\u{1F6FF}]', ''
    $anchor = $anchor -replace '[\u{1F1E0}-\u{1F1FF}]', ''
    
    # Convert to lowercase
    $anchor = $anchor.ToLower()
    
    # Replace spaces with hyphens
    $anchor = $anchor -replace '\s+', '-'
    
    # Remove special characters except hyphens
    $anchor = $anchor -replace '[^a-z0-9\-]', ''
    
    # Remove multiple consecutive hyphens
    $anchor = $anchor -replace '-+', '-'
    
    # Remove leading and trailing hyphens
    $anchor = $anchor.Trim('-')
    
    return $anchor
}

function Get-SectionHeaders {
    param([string]$filePath)
    
    $headers = @()
    $content = Get-Content $filePath -Encoding UTF8
    
    foreach ($line in $content) {
        if ($line -match '^(#+)\s+(.+)$') {
            $level = $matches[1].Length
            $headerText = $matches[2].Trim()
            $anchor = Convert-ToGitHubAnchor $headerText
            
            $headers += @{
                Level = $level
                Text = $headerText
                Anchor = $anchor
                Line = $line
            }
        }
    }
    
    return $headers
}

function Find-BestHeaderMatch {
    param(
        [string]$linkText,
        [array]$headers
    )
    
    # Remove emoji from link text for comparison
    $cleanLinkText = Convert-ToGitHubAnchor $linkText
    
    # Try exact anchor match first
    $exactMatch = $headers | Where-Object { $_.Anchor -eq $cleanLinkText }
    if ($exactMatch) {
        return $exactMatch[0]
    }
    
    # Try partial matches
    $partialMatches = $headers | Where-Object { 
        $_.Anchor -like "*$cleanLinkText*" -or $cleanLinkText -like "*$($_.Anchor)*"
    }
    
    if ($partialMatches) {
        # Return the best match (shortest difference in length)
        return ($partialMatches | Sort-Object { [Math]::Abs($_.Anchor.Length - $cleanLinkText.Length) })[0]
    }
    
    return $null
}

function Fix-QuickNavLinks {
    param([string]$filePath)
    
    Write-Host "📋 Processing: $(Split-Path $filePath -Leaf)" -ForegroundColor Cyan
    
    $content = Get-Content $filePath -Encoding UTF8 -Raw
    $headers = Get-SectionHeaders $filePath
    
    # Find Quick Navigation section
    if ($content -notmatch '(?s)##[^#]*Quick Navigation.*?\|(.*?\|.*?\|.*?\|.*?\n)+') {
        Write-Host "   ⏭️  No Quick Navigation section found" -ForegroundColor Yellow
        return $false
    }
    
    $quickNavMatch = $matches[0]
    $updatedQuickNav = $quickNavMatch
    $changesFound = $false
    
    # Find all links in the Quick Navigation table
    $linkPattern = '\[([^\]]+)\]\(#([^)]+)\)'
    $links = [regex]::Matches($quickNavMatch, $linkPattern)
    
    foreach ($link in $links) {
        $linkText = $link.Groups[1].Value
        $currentAnchor = $link.Groups[2].Value
        
        # Find the best matching header
        $bestMatch = Find-BestHeaderMatch $linkText $headers
        
        if ($bestMatch) {
            $correctAnchor = $bestMatch.Anchor
            
            if ($currentAnchor -ne $correctAnchor) {
                Write-Host "   🔧 Fixing: $linkText" -ForegroundColor Green
                Write-Host "      Old: #$currentAnchor" -ForegroundColor Red
                Write-Host "      New: #$correctAnchor" -ForegroundColor Green
                Write-Host "      Matches header: $($bestMatch.Text)" -ForegroundColor Blue
                
                $updatedQuickNav = $updatedQuickNav -replace "\Q$($link.Value)\E", "[$linkText](#$correctAnchor)"
                $changesFound = $true
            }
        } else {
            Write-Host "   ⚠️  No matching header found for: $linkText" -ForegroundColor Yellow
        }
    }
    
    if ($changesFound) {
        if (-not $DryRun) {
            $newContent = $content -replace [regex]::Escape($quickNavMatch), $updatedQuickNav
            Set-Content $filePath -Value $newContent -Encoding UTF8 -NoNewline
            Write-Host "   ✅ File updated successfully" -ForegroundColor Green
        } else {
            Write-Host "   🔍 Would update file (dry run)" -ForegroundColor Yellow
        }
        return $true
    } else {
        Write-Host "   ✅ No changes needed" -ForegroundColor Green
        return $false
    }
}

# Main execution
Write-Host "🔧 Intelligent Quick Navigation Header Fixer" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Magenta
Write-Host ""

if ($DryRun) {
    Write-Host "🔍 DRY RUN MODE - No files will be modified" -ForegroundColor Yellow
    Write-Host ""
}

$docsPath = "docs"
$mdFiles = Get-ChildItem $docsPath -Filter "*.md" | Sort-Object Name

$totalFiles = 0
$filesChanged = 0

foreach ($file in $mdFiles) {
    $totalFiles++
    $changed = Fix-QuickNavLinks $file.FullName
    if ($changed) { $filesChanged++ }
    Write-Host ""
}

Write-Host "📊 Summary:" -ForegroundColor Magenta
Write-Host "=" * 12 -ForegroundColor Magenta
Write-Host "Files processed: $totalFiles"
Write-Host "Files changed: $filesChanged"
Write-Host ""

if ($filesChanged -gt 0 -and -not $DryRun) {
    Write-Host "✅ Quick Navigation links have been intelligently fixed!" -ForegroundColor Green
    Write-Host "Don't forget to commit the changes." -ForegroundColor Yellow
} elseif ($DryRun) {
    Write-Host "🔍 Dry run complete. Use without -DryRun to apply changes." -ForegroundColor Yellow
}
