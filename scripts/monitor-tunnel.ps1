# Cloudflare Tunnel Monitor and Auto-Restart Script (PowerShell)
# This script monitors the cloudflared tunnel and automatically restarts it if it crashes
# It also logs new tunnel URLs and can send notifications

param(
    [int]$CheckInterval = 30,  # Check every 30 seconds
    [int]$LocalPort = 8080
)

$TUNNEL_LOG = "tunnel.log"
$TUNNEL_PID_FILE = "tunnel.pid"
$TUNNEL_URL_FILE = "tunnel_url.txt"
$TUNNEL_HISTORY_FILE = "tunnel_history.log"

# Function to log messages
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        default { "Cyan" }
    }
    
    Write-Host "[$timestamp] " -NoNewline -ForegroundColor $color
    Write-Host $Message
}

# Function to extract tunnel URL from log
function Get-TunnelUrl {
    if (Test-Path $TUNNEL_LOG) {
        $content = Get-Content $TUNNEL_LOG -Raw
        if ($content -match 'https://[a-zA-Z0-9-]+\.trycloudflare\.com') {
            return $matches[0]
        }
    }
    return $null
}

# Function to check if tunnel process is running
function Test-TunnelRunning {
    if (Test-Path $TUNNEL_PID_FILE) {
        $pid = Get-Content $TUNNEL_PID_FILE
        try {
            $process = Get-Process -Id $pid -ErrorAction Stop
            return $true
        } catch {
            return $false
        }
    }
    return $false
}

# Function to check if tunnel URL is accessible
function Test-TunnelAccessible {
    param([string]$Url)
    
    if ([string]::IsNullOrEmpty($Url)) {
        return $false
    }
    
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Function to start cloudflared tunnel
function Start-Tunnel {
    Write-Log "Starting Cloudflare tunnel..." "INFO"
    
    # Clean up old log
    if (Test-Path $TUNNEL_LOG) {
        Remove-Item $TUNNEL_LOG -Force
    }
    
    # Start cloudflared in background
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "cloudflared.exe"
    $processInfo.Arguments = "tunnel --url http://localhost:$LocalPort"
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    
    # Redirect output to log file
    $process.add_OutputDataReceived({
        param($sender, $e)
        if ($e.Data) {
            Add-Content -Path $TUNNEL_LOG -Value $e.Data
        }
    })
    $process.add_ErrorDataReceived({
        param($sender, $e)
        if ($e.Data) {
            Add-Content -Path $TUNNEL_LOG -Value $e.Data
        }
    })
    
    $process.Start() | Out-Null
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
    
    # Save PID
    $process.Id | Out-File -FilePath $TUNNEL_PID_FILE -Force
    
    Write-Log "Tunnel process started with PID $($process.Id)" "INFO"
    
    # Wait for tunnel URL to appear (up to 60 seconds)
    Write-Log "Waiting for tunnel URL..." "INFO"
    $tunnelUrl = $null
    for ($i = 1; $i -le 12; $i++) {
        Start-Sleep -Seconds 5
        $tunnelUrl = Get-TunnelUrl
        if ($tunnelUrl) {
            break
        }
    }
    
    if (-not $tunnelUrl) {
        Write-Log "Failed to get tunnel URL after 60 seconds" "ERROR"
        Write-Log "Tunnel log:" "ERROR"
        if (Test-Path $TUNNEL_LOG) {
            Get-Content $TUNNEL_LOG | Write-Host
        }
        return $false
    }
    
    # Save tunnel URL
    $tunnelUrl | Out-File -FilePath $TUNNEL_URL_FILE -Force
    
    # Log to history
    $historyEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] New tunnel URL: $tunnelUrl"
    Add-Content -Path $TUNNEL_HISTORY_FILE -Value $historyEntry
    
    # Verify tunnel is accessible
    Write-Log "Verifying tunnel accessibility..." "INFO"
    Start-Sleep -Seconds 5
    
    if (Test-TunnelAccessible $tunnelUrl) {
        Write-Log "Tunnel is accessible at: $tunnelUrl" "SUCCESS"
    } else {
        Write-Log "Tunnel URL exists but may not be accessible yet (Cloudflare propagation delay)" "WARNING"
    }
    
    # Display the URL prominently
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          🌐 NEW CLOUDFLARE TUNNEL URL                      ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   $tunnelUrl" -ForegroundColor Green
    Write-Host ""
    
    # Send notification if configured
    Send-Notification "🌐 New Tunnel URL" $tunnelUrl
    
    return $true
}

# Function to stop tunnel
function Stop-Tunnel {
    if (Test-Path $TUNNEL_PID_FILE) {
        $pid = Get-Content $TUNNEL_PID_FILE
        Write-Log "Stopping tunnel process (PID: $pid)..." "INFO"
        try {
            Stop-Process -Id $pid -Force -ErrorAction Stop
            Write-Log "Tunnel stopped" "SUCCESS"
        } catch {
            Write-Log "Failed to stop tunnel: $_" "WARNING"
        }
        Remove-Item $TUNNEL_PID_FILE -Force -ErrorAction SilentlyContinue
    }
}

# Function to send notification
function Send-Notification {
    param(
        [string]$Title,
        [string]$Message
    )
    
    # Try ntfy if configured
    if ($env:NTFY_URL -and $env:NTFY_TOPIC) {
        $ntfyEndpoint = "$($env:NTFY_URL)/$($env:NTFY_TOPIC)"
        try {
            $headers = @{
                "Title" = $Title
            }
            if ($env:NTFY_TOKEN) {
                $headers["Authorization"] = "Bearer $($env:NTFY_TOKEN)"
            }
            Invoke-RestMethod -Uri $ntfyEndpoint -Method Post -Headers $headers -Body $Message -ErrorAction SilentlyContinue | Out-Null
        } catch {
            # Silently fail
        }
    }
    
    # Try Discord if configured
    if ($env:DISCORD_WEBHOOK_URL) {
        try {
            $body = @{
                content = "**$Title**`n$Message"
            } | ConvertTo-Json
            Invoke-RestMethod -Uri $env:DISCORD_WEBHOOK_URL -Method Post -ContentType "application/json" -Body $body -ErrorAction SilentlyContinue | Out-Null
        } catch {
            # Silently fail
        }
    }
}

# Function to monitor tunnel
function Start-TunnelMonitor {
    Write-Log "Starting tunnel monitor (checking every ${CheckInterval}s)..." "INFO"
    
    $consecutiveFailures = 0
    $lastUrl = ""
    
    while ($true) {
        # Check if process is running
        if (-not (Test-TunnelRunning)) {
            Write-Log "Tunnel process is not running!" "ERROR"
            $consecutiveFailures++
            
            if ($consecutiveFailures -ge 3) {
                Write-Log "Tunnel has failed 3 times consecutively. Restarting..." "ERROR"
                Send-Notification "🚨 Tunnel Crashed" "Tunnel process crashed. Attempting restart..."
                
                if (Start-Tunnel) {
                    $consecutiveFailures = 0
                    Write-Log "Tunnel restarted successfully" "SUCCESS"
                } else {
                    Write-Log "Failed to restart tunnel. Will retry in ${CheckInterval}s..." "ERROR"
                }
            } else {
                Write-Log "Tunnel failure $consecutiveFailures/3. Will check again in ${CheckInterval}s..." "WARNING"
            }
        } else {
            # Process is running, check if URL is accessible
            $currentUrl = Get-TunnelUrl
            
            if ($currentUrl) {
                # Check if URL changed
                if ($currentUrl -ne $lastUrl) {
                    Write-Log "Detected new tunnel URL: $currentUrl" "INFO"
                    $currentUrl | Out-File -FilePath $TUNNEL_URL_FILE -Force
                    $historyEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] URL changed: $currentUrl"
                    Add-Content -Path $TUNNEL_HISTORY_FILE -Value $historyEntry
                    Send-Notification "🔄 Tunnel URL Changed" $currentUrl
                    $lastUrl = $currentUrl
                }
                
                # Verify accessibility
                if (Test-TunnelAccessible $currentUrl) {
                    # Reset failure counter on success
                    if ($consecutiveFailures -gt 0) {
                        Write-Log "Tunnel recovered and is accessible" "SUCCESS"
                        $consecutiveFailures = 0
                    }
                } else {
                    Write-Log "Tunnel URL exists but is not accessible" "WARNING"
                    $consecutiveFailures++
                }
            } else {
                Write-Log "No tunnel URL found in log" "WARNING"
                $consecutiveFailures++
            }
        }
        
        Start-Sleep -Seconds $CheckInterval
    }
}

# Handle script termination
$cleanup = {
    Write-Log "Received termination signal. Cleaning up..." "INFO"
    Stop-Tunnel
    exit 0
}

Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $cleanup | Out-Null

# Main script
Write-Log "Cloudflare Tunnel Monitor v1.0" "INFO"
Write-Log "================================" "INFO"

# Check if cloudflared is installed
try {
    $null = Get-Command cloudflared.exe -ErrorAction Stop
} catch {
    Write-Log "cloudflared.exe is not installed or not in PATH!" "ERROR"
    Write-Log "Download it from: https://github.com/cloudflare/cloudflared/releases" "ERROR"
    exit 1
}

# Check if tunnel is already running
if (Test-TunnelRunning) {
    Write-Log "Tunnel is already running" "INFO"
    $currentUrl = Get-TunnelUrl
    if ($currentUrl) {
        Write-Log "Current URL: $currentUrl" "INFO"
    }
} else {
    # Start tunnel for the first time
    if (-not (Start-Tunnel)) {
        Write-Log "Failed to start tunnel" "ERROR"
        exit 1
    }
}

# Start monitoring
Start-TunnelMonitor
