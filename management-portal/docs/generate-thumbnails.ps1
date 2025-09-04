<#
Script: generate-thumbnails.ps1
Purpose: Generate thumbnails for images in this folder and write them to ./thumbnails with a -thumb suffix.
Requirements:
 - ImageMagick (magick) recommended
 - On Windows, PowerShell can use System.Drawing as a fallback

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\generate-thumbnails.ps1 -Width 300
#>

param(
    [int]$Width = 300,
    [string]$SourceDir = ".",
    [string]$OutDir = "./thumbnails",
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

# Collect images using explicit patterns to avoid Get-ChildItem -Include pitfalls
$images = @()
$patterns = @('*.png','*.jpg','*.jpeg','*.gif')
foreach ($p in $patterns) {
    $images += Get-ChildItem -Path (Join-Path $SourceDir $p) -File -ErrorAction SilentlyContinue
}
# Remove duplicates and normalize
$images = $images | Sort-Object -Property FullName -Unique

Write-Output "Found $($images.Count) image(s) in $SourceDir"

foreach ($img in $images) {
    $thumbName = [System.IO.Path]::Combine($OutDir, "$($img.BaseName)-thumb$($img.Extension)")
    if ((Test-Path $thumbName) -and -not $Force) {
        Write-Output "Skipping existing: $thumbName"
        continue
    }

    # Prefer ImageMagick if available
    $magick = Get-Command magick -ErrorAction SilentlyContinue
    if ($magick) {
        Write-Output "Creating thumbnail via ImageMagick: $thumbName"
        # Use 'magick' in a portable way: magick input -auto-orient -thumbnail {Width}x output
        & magick "$($img.FullName)" -auto-orient -thumbnail ${Width}x "$thumbName"
        continue
    }

    # Fallback: use .NET System.Drawing (Windows only)
    try {
        Add-Type -AssemblyName System.Drawing
        $src = [System.Drawing.Image]::FromFile($img.FullName)
        $ratio = [double]$Width / $src.Width
        $newHeight = [int]([math]::Round($src.Height * $ratio))
        $thumb = New-Object System.Drawing.Bitmap $Width, $newHeight
        $g = [System.Drawing.Graphics]::FromImage($thumb)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($src, 0, 0, $Width, $newHeight)
        $thumb.Save($thumbName, $src.RawFormat)
        $g.Dispose()
        $thumb.Dispose()
        $src.Dispose()
        Write-Output "Created thumbnail: $thumbName"
    }
    catch {
        Write-Warning "Failed to create thumbnail for $($img.Name): $_"
    }
}

Write-Output "Done. Thumbnails are in: $OutDir"
