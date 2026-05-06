# Script to get the current tunnel URL from various sources
# Priority: 1. Local file, 2. Supabase, 3. Tunnel log

$TUNNEL_URL_FILE = "tunnel_url.txt"
$TUNNEL_LOG = "tunnel.log"

Write-Host "🔍 Searching for current tunnel URL..." -ForegroundColor Cyan
Write-Host ""

# Method 1: Check local file
if (Test-Path $TUNNEL_URL_FILE) {
    $url = Get-Content $TUNNEL_URL_FILE -Raw
    $url = $url.Trim()
    
    if ($url) {
        Write-Host "✓ Found in local file:" -ForegroundColor Green
        Write-Host "  $url"
        Write-Host ""
        
        # Verify it's accessible
        try {
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            Write-Host "✓ Tunnel is accessible" -ForegroundColor Green
        } catch {
            Write-Host "⚠ Tunnel URL exists but may not be accessible" -ForegroundColor Yellow
        }
        exit 0
    }
}

# Method 2: Check Supabase
if ($env:SUPABASE_URL -and $env:SUPABASE_API_KEY) {
    Write-Host "Checking Supabase..."
    try {
        $headers = @{
            "apikey" = $env:SUPABASE_API_KEY
            "Authorization" = "Bearer $($env:SUPABASE_API_KEY)"
        }
        $response = Invoke-RestMethod -Uri "$($env:SUPABASE_URL)/rest/v1/current_tunnel?select=url" -Headers $headers -ErrorAction Stop
        
        if ($response -and $response[0].url) {
            $url = $response[0].url
            Write-Host "✓ Found in Supabase:" -ForegroundColor Green
            Write-Host "  $url"
            Write-Host ""
            
            # Save to local file for faster access next time
            $url | Out-File -FilePath $TUNNEL_URL_FILE -Force
            
            # Verify it's accessible
            try {
                $testResponse = Invoke-WebRequest -Uri $url -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
                Write-Host "✓ Tunnel is accessible" -ForegroundColor Green
            } catch {
                Write-Host "⚠ Tunnel URL exists but may not be accessible" -ForegroundColor Yellow
            }
            exit 0
        }
    } catch {
        # Silently continue to next method
    }
}

# Method 3: Check tunnel log
if (Test-Path $TUNNEL_LOG) {
    Write-Host "Checking tunnel log..."
    $content = Get-Content $TUNNEL_LOG -Raw
    
    if ($content -match 'https://[a-zA-Z0-9-]+\.trycloudflare\.com') {
        $url = $matches[0]
        Write-Host "✓ Found in tunnel log:" -ForegroundColor Green
        Write-Host "  $url"
        Write-Host ""
        
        # Save to local file
        $url | Out-File -FilePath $TUNNEL_URL_FILE -Force
        
        # Verify it's accessible
        try {
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            Write-Host "✓ Tunnel is accessible" -ForegroundColor Green
        } catch {
            Write-Host "⚠ Tunnel URL exists but may not be accessible" -ForegroundColor Yellow
        }
        exit 0
    }
}

# Not found
Write-Host "✗ No tunnel URL found" -ForegroundColor Red
Write-Host ""
Write-Host "Possible reasons:"
Write-Host "  • Tunnel is not running"
Write-Host "  • Tunnel hasn't started yet"
Write-Host "  • Tunnel log file doesn't exist"
Write-Host ""
Write-Host "To start the tunnel monitor:"
Write-Host "  .\scripts\monitor-tunnel.ps1"
exit 1
