# PowerShell script to handle incomplete recordings after disk full events
# This script helps you identify and manage partial recordings

$VIDEOS_DIR = ".\videos"
$COMPLETED_DIR = ".\videos\completed"
$MIN_SIZE_MB = 10  # Minimum size in MB to consider keeping

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Incomplete Recording Handler" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Create completed directory if it doesn't exist
if (-not (Test-Path $COMPLETED_DIR)) {
    New-Item -ItemType Directory -Path $COMPLETED_DIR | Out-Null
}

# Find all video files in videos directory (not in completed)
Write-Host "Scanning for video files..." -ForegroundColor Yellow
Write-Host ""

$files = Get-ChildItem -Path $VIDEOS_DIR -Include *.mp4,*.ts -Recurse -File | 
    Where-Object { $_.FullName -notlike "*\completed\*" -and $_.Name -notlike "*.finalizing.mp4" }

$total_files = 0
$small_files = 0
$total_size = 0

foreach ($file in $files) {
    $size_mb = [math]::Round($file.Length / 1MB, 2)
    $total_files++
    $total_size += $size_mb
    
    if ($size_mb -lt $MIN_SIZE_MB) {
        Write-Host "❌ SMALL FILE: $($file.Name) (${size_mb}MB)" -ForegroundColor Red
        Write-Host "   Path: $($file.FullName)" -ForegroundColor Gray
        Write-Host "   Recommendation: Delete (too small)" -ForegroundColor Gray
        $small_files++
    } else {
        Write-Host "✅ KEEPABLE: $($file.Name) (${size_mb}MB)" -ForegroundColor Green
        Write-Host "   Path: $($file.FullName)" -ForegroundColor Gray
        Write-Host "   Recommendation: Keep or move to completed/" -ForegroundColor Gray
    }
    Write-Host ""
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Total files found: $total_files" -ForegroundColor White
Write-Host "  Small files (<${MIN_SIZE_MB}MB): $small_files" -ForegroundColor White
Write-Host "  Total size: ${total_size}MB" -ForegroundColor White
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Ask user what to do
if ($total_files -eq 0) {
    Write-Host "No incomplete recordings found." -ForegroundColor Green
    exit 0
}

Write-Host "What would you like to do?" -ForegroundColor Yellow
Write-Host "1) Delete all small files (<${MIN_SIZE_MB}MB)"
Write-Host "2) Move all files to completed/"
Write-Host "3) Do nothing (manual handling)"
$choice = Read-Host "Enter choice (1-3)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "Deleting small files..." -ForegroundColor Yellow
        foreach ($file in $files) {
            $size_mb = [math]::Round($file.Length / 1MB, 2)
            if ($size_mb -lt $MIN_SIZE_MB) {
                Write-Host "Deleting: $($file.Name)" -ForegroundColor Red
                Remove-Item $file.FullName -Force
            }
        }
        Write-Host "✓ Small files deleted" -ForegroundColor Green
    }
    "2" {
        Write-Host ""
        Write-Host "Moving files to completed/..." -ForegroundColor Yellow
        foreach ($file in $files) {
            Write-Host "Moving: $($file.Name)" -ForegroundColor Cyan
            Move-Item $file.FullName -Destination $COMPLETED_DIR -Force
        }
        Write-Host "✓ Files moved to completed/" -ForegroundColor Green
    }
    "3" {
        Write-Host "No action taken. Handle files manually." -ForegroundColor Gray
    }
    default {
        Write-Host "Invalid choice. No action taken." -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
