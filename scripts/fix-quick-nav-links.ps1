#!/usr/bin/env pwsh
# Fix all Quick Navigation anchor links across documentation files
# This script corrects GitHub anchor generation rules

param(
    [switch]$DryRun = $false
)

Write-Host "🔧 Quick Navigation Link Fixer" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

# Function to convert text to GitHub anchor format
function Convert-ToGitHubAnchor {
    param([string]$text)
    
    # Remove emojis and special characters at the beginning
    $cleaned = $text -replace '^[🎯🏗️🏛🚀🔒📊🌱🔐🌐🛡️✅🛠️📚🧭🧪🔧⚡🗃️🧰🔍📞🗂️🧩🌀🏷️📝🎭💰🏠📈🚨🔄📋🏢💡📖🔗🎨📱🌍🗄️🎛️🧱🏷️🚪📞]+\s*', ''
    
    # Convert to lowercase and trim
    $cleaned = $cleaned.Trim().ToLower()
    
    # Handle special cases for better anchor matching
    $cleaned = $cleaned -replace '\s*\(\s*functions\s*\+\s*emulator\s*\)', '-functions-emulator'
    $cleaned = $cleaned -replace '\s*\&\s*', '-&-'
    $cleaned = $cleaned -replace '\s*/\s*', ''  # Remove slashes
    $cleaned = $cleaned -replace '\s+', '-'     # Replace spaces with hyphens
    $cleaned = $cleaned -replace '[^\w\-&]', '' # Keep only word chars, hyphens, and &
    $cleaned = $cleaned -replace '--+', '-'     # Multiple hyphens to single
    $cleaned = $cleaned -replace '^-+|-+$', ''  # Remove leading/trailing hyphens
    
    return $cleaned
}

# Get all markdown files in docs directory
$docFiles = Get-ChildItem -Path "docs\*.md" -File | Where-Object { 
    $_.Name -notlike "*template*" -and 
    $_.Name -ne "DOCS.md" 
}

$totalFiles = 0
$totalLinks = 0
$fixedLinks = 0

foreach ($file in $docFiles) {
    Write-Host "`n📋 Processing: $($file.Name)" -ForegroundColor Yellow
    
    $content = Get-Content -Path $file.FullName -Raw
    $originalContent = $content
    
    # Check if file has Quick Navigation section
    if ($content -notmatch "## 🧭 Quick Navigation") {
        Write-Host "   ⏭️  No Quick Navigation section found" -ForegroundColor Gray
        continue
    }
    
    $totalFiles++
    
    # Extract and fix Quick Navigation table
    $pattern = '\|\s*\[([^\]]+)\]\(([^)]+)\)\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|'
    $linkMatches = [regex]::Matches($content, $pattern)
    
    foreach ($match in $linkMatches) {
        $linkText = $match.Groups[1].Value.Trim()
        $currentAnchor = $match.Groups[2].Value.Trim()
        $focusArea = $match.Groups[3].Value.Trim()
        $bestFor = $match.Groups[4].Value.Trim()
        
        # Skip external links and relative links
        if ($currentAnchor.StartsWith("http") -or $currentAnchor.StartsWith("./")) {
            continue
        }
        
        $totalLinks++
        
        # Generate correct anchor
        $correctAnchor = "#" + (Convert-ToGitHubAnchor $linkText)
        
        if ($currentAnchor -ne $correctAnchor) {
            Write-Host "   🔧 Fixing: $linkText" -ForegroundColor Green
            Write-Host "      Old: $currentAnchor" -ForegroundColor Red
            Write-Host "      New: $correctAnchor" -ForegroundColor Green
            
            # Replace the specific link
            $oldLink = "[$linkText]($currentAnchor)"
            $newLink = "[$linkText]($correctAnchor)"
            $content = $content.Replace($oldLink, $newLink)
            $fixedLinks++
        }
    }
    
    # Write the file if changes were made and not in dry run mode
    if ($content -ne $originalContent) {
        if (-not $DryRun) {
            Set-Content -Path $file.FullName -Value $content -NoNewline
            Write-Host "   ✅ File updated successfully" -ForegroundColor Green
        } else {
            Write-Host "   🔍 DRY RUN: Would update file" -ForegroundColor Cyan
        }
    } else {
        Write-Host "   ✅ No changes needed" -ForegroundColor Green
    }
}

# Summary
Write-Host "`n📊 Summary:" -ForegroundColor Cyan
Write-Host "============" -ForegroundColor Cyan
Write-Host "Files processed: $totalFiles" -ForegroundColor White
Write-Host "Total links checked: $totalLinks" -ForegroundColor White
Write-Host "Links fixed: $fixedLinks" -ForegroundColor ($fixedLinks -gt 0 ? "Green" : "White")

if ($DryRun) {
    Write-Host "`n🔍 This was a DRY RUN. Use without -DryRun to apply changes." -ForegroundColor Yellow
} elseif ($fixedLinks -gt 0) {
    Write-Host "`n✅ All Quick Navigation links have been fixed!" -ForegroundColor Green
    Write-Host "Don't forget to commit the changes." -ForegroundColor Yellow
} else {
    Write-Host "`n✅ All Quick Navigation links are already correct!" -ForegroundColor Green
}
