# Fix Thumbnail URLs in Database
# This script converts Pixhost show URLs to direct image URLs

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     🔧 Fixing Thumbnail URLs in Database                  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$databaseDir = "database"
if (-not (Test-Path $databaseDir)) {
    Write-Host "❌ Database directory does not exist" -ForegroundColor Red
    exit 1
}

$totalFixed = 0
$totalFiles = 0

# Function to convert Pixhost show URL to direct image URL
function Convert-PixhostURL {
    param([string]$showURL)
    
    if ($showURL -match 'https://pixhost\.to/show/(\d+)/(\d+_.+)') {
        $serverNum = $matches[1]
        $imageFile = $matches[2]
        $imgServer = "img$serverNum"
        return "https://$imgServer.pixhost.to/images/$serverNum/$imageFile"
    }
    
    return $showURL
}

# Find all recordings.json files
$files = Get-ChildItem -Path $databaseDir -Recurse -Filter "recordings.json"

foreach ($file in $files) {
    $totalFiles++
    Write-Host "📁 Processing: $($file.FullName)" -ForegroundColor Yellow
    
    try {
        # Read and parse JSON
        $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
        
        if (-not $content.recordings) {
            Write-Host "   ⚠️  No recordings array found" -ForegroundColor Yellow
            continue
        }
        
        $modified = $false
        $fixedInFile = 0
        
        # Fix each recording's thumbnail URL
        foreach ($recording in $content.recordings) {
            if ($recording.thumbnail_link -and $recording.thumbnail_link -like "*pixhost.to/show/*") {
                $oldURL = $recording.thumbnail_link
                $newURL = Convert-PixhostURL -showURL $oldURL
                
                if ($newURL -ne $oldURL) {
                    $recording.thumbnail_link = $newURL
                    $modified = $true
                    $fixedInFile++
                    Write-Host "   ✓ Fixed: $(Split-Path $oldURL -Leaf)" -ForegroundColor Green
                }
            }
        }
        
        if ($modified) {
            # Write back to file
            $content | ConvertTo-Json -Depth 10 | Set-Content $file.FullName -Encoding UTF8
            Write-Host "   ✅ Updated $fixedInFile thumbnail(s) in this file" -ForegroundColor Green
            $totalFixed += $fixedInFile
        } else {
            Write-Host "   ℹ️  No thumbnails needed fixing" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "   ❌ Error processing file: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    Migration Complete                      ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "📊 Files processed: $totalFiles" -ForegroundColor White
Write-Host "✅ Thumbnails fixed: $totalFixed" -ForegroundColor Green
Write-Host ""
