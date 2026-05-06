#!/bin/bash

# Script to handle incomplete recordings after disk full events
# This script helps you identify and manage partial recordings

VIDEOS_DIR="./videos"
COMPLETED_DIR="./videos/completed"
MIN_SIZE_MB=10  # Minimum size in MB to consider keeping

echo "=================================================="
echo "  Incomplete Recording Handler"
echo "=================================================="
echo ""

# Create completed directory if it doesn't exist
mkdir -p "$COMPLETED_DIR"

# Find all video files in videos directory (not in completed)
echo "Scanning for video files..."
echo ""

total_files=0
small_files=0
total_size=0

while IFS= read -r -d '' file; do
    # Skip if in completed directory
    if [[ "$file" == *"/completed/"* ]]; then
        continue
    fi
    
    # Get file size in MB
    size_bytes=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    size_mb=$((size_bytes / 1024 / 1024))
    
    total_files=$((total_files + 1))
    total_size=$((total_size + size_mb))
    
    filename=$(basename "$file")
    
    if [ $size_mb -lt $MIN_SIZE_MB ]; then
        echo "❌ SMALL FILE: $filename (${size_mb}MB)"
        echo "   Path: $file"
        echo "   Recommendation: Delete (too small)"
        small_files=$((small_files + 1))
    else
        echo "✅ KEEPABLE: $filename (${size_mb}MB)"
        echo "   Path: $file"
        echo "   Recommendation: Keep or move to completed/"
    fi
    echo ""
done < <(find "$VIDEOS_DIR" -maxdepth 2 -type f \( -name "*.mp4" -o -name "*.ts" \) ! -name "*.finalizing.mp4" -print0)

echo "=================================================="
echo "Summary:"
echo "  Total files found: $total_files"
echo "  Small files (<${MIN_SIZE_MB}MB): $small_files"
echo "  Total size: ${total_size}MB"
echo "=================================================="
echo ""

# Ask user what to do
if [ $total_files -eq 0 ]; then
    echo "No incomplete recordings found."
    exit 0
fi

echo "What would you like to do?"
echo "1) Delete all small files (<${MIN_SIZE_MB}MB)"
echo "2) Move all files to completed/"
echo "3) Do nothing (manual handling)"
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        echo ""
        echo "Deleting small files..."
        while IFS= read -r -d '' file; do
            if [[ "$file" == *"/completed/"* ]]; then
                continue
            fi
            size_bytes=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            size_mb=$((size_bytes / 1024 / 1024))
            if [ $size_mb -lt $MIN_SIZE_MB ]; then
                echo "Deleting: $(basename "$file")"
                rm "$file"
            fi
        done < <(find "$VIDEOS_DIR" -maxdepth 2 -type f \( -name "*.mp4" -o -name "*.ts" \) ! -name "*.finalizing.mp4" -print0)
        echo "✓ Small files deleted"
        ;;
    2)
        echo ""
        echo "Moving files to completed/..."
        while IFS= read -r -d '' file; do
            if [[ "$file" == *"/completed/"* ]]; then
                continue
            fi
            filename=$(basename "$file")
            echo "Moving: $filename"
            mv "$file" "$COMPLETED_DIR/"
        done < <(find "$VIDEOS_DIR" -maxdepth 2 -type f \( -name "*.mp4" -o -name "*.ts" \) ! -name "*.finalizing.mp4" -print0)
        echo "✓ Files moved to completed/"
        ;;
    3)
        echo "No action taken. Handle files manually."
        ;;
    *)
        echo "Invalid choice. No action taken."
        ;;
esac

echo ""
echo "Done!"
