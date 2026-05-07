# Fix Thumbnail URLs - Simple Version
Write-Host "Fixing thumbnail URLs in database..." -ForegroundColor Cyan

$totalFixed = 0
$files = Get-ChildItem -Path "database" -Recurse -Filter "recordings.json"

foreach ($file in $files) {
    Write-Host "Processing: $($file.Name)" -ForegroundColor Yellow
    
    $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
    $modified = $false
    
    foreach ($recording in $content.recordings) {
        if ($recording.thumbnail_link -like "*pixhost.to/show/*") {
            if ($recording.thumbnail_link -match 'https://pixhost\.to/show/(\d+)/(\d+_.+)') {
                $serverNum = $matches[1]
                $imageFile = $matches[2]
                $newURL = "https://img$serverNum.pixhost.to/images/$serverNum/$imageFile"
                $recording.thumbnail_link = $newURL
                $modified = $true
                $totalFixed++
                Write-Host "  Fixed: $imageFile" -ForegroundColor Green
            }
        }
    }
    
    if ($modified) {
        $content | ConvertTo-Json -Depth 10 | Set-Content $file.FullName -Encoding UTF8
        Write-Host "  Saved changes" -ForegroundColor Green
    }
}

Write-Host "`nTotal thumbnails fixed: $totalFixed" -ForegroundColor Green
