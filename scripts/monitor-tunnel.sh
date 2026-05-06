#!/bin/bash

# Cloudflare Tunnel Monitor and Auto-Restart Script
# This script monitors the cloudflared tunnel and automatically restarts it if it crashes
# It also logs new tunnel URLs and can send notifications

TUNNEL_LOG="tunnel.log"
TUNNEL_PID_FILE="tunnel.pid"
TUNNEL_URL_FILE="tunnel_url.txt"
TUNNEL_HISTORY_FILE="tunnel_history.log"
CHECK_INTERVAL=30  # Check every 30 seconds
LOCAL_PORT=8080

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1"
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Function to extract tunnel URL from log
get_tunnel_url() {
    grep -oP 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" | tail -1
}

# Function to check if tunnel process is running
is_tunnel_running() {
    if [ -f "$TUNNEL_PID_FILE" ]; then
        PID=$(cat "$TUNNEL_PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0  # Running
        fi
    fi
    return 1  # Not running
}

# Function to check if tunnel URL is accessible
is_tunnel_accessible() {
    local url="$1"
    if [ -z "$url" ]; then
        return 1
    fi
    
    # Try to access the tunnel URL
    if curl -sf --max-time 10 "$url" > /dev/null 2>&1; then
        return 0  # Accessible
    fi
    return 1  # Not accessible
}

# Function to start cloudflared tunnel
start_tunnel() {
    log "Starting Cloudflare tunnel..."
    
    # Clean up old log
    > "$TUNNEL_LOG"
    
    # Start cloudflared in background
    cloudflared tunnel --url "http://localhost:$LOCAL_PORT" > "$TUNNEL_LOG" 2>&1 &
    echo $! > "$TUNNEL_PID_FILE"
    
    log "Tunnel process started with PID $(cat $TUNNEL_PID_FILE)"
    
    # Wait for tunnel URL to appear (up to 60 seconds)
    log "Waiting for tunnel URL..."
    local TUNNEL_URL=""
    for i in $(seq 1 12); do
        TUNNEL_URL=$(get_tunnel_url)
        if [ -n "$TUNNEL_URL" ]; then
            break
        fi
        sleep 5
    done
    
    if [ -z "$TUNNEL_URL" ]; then
        error "Failed to get tunnel URL after 60 seconds"
        error "Tunnel log:"
        cat "$TUNNEL_LOG"
        return 1
    fi
    
    # Save tunnel URL
    echo "$TUNNEL_URL" > "$TUNNEL_URL_FILE"
    
    # Log to history
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] New tunnel URL: $TUNNEL_URL" >> "$TUNNEL_HISTORY_FILE"
    
    # Verify tunnel is accessible
    log "Verifying tunnel accessibility..."
    sleep 5  # Give it a moment to propagate
    
    if is_tunnel_accessible "$TUNNEL_URL"; then
        success "Tunnel is accessible at: $TUNNEL_URL"
    else
        warning "Tunnel URL exists but may not be accessible yet (Cloudflare propagation delay)"
    fi
    
    # Display the URL prominently
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║          🌐 NEW CLOUDFLARE TUNNEL URL                      ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "   $TUNNEL_URL"
    echo ""
    
    # Send notification if configured
    send_notification "🌐 New Tunnel URL" "$TUNNEL_URL"
    
    return 0
}

# Function to stop tunnel
stop_tunnel() {
    if [ -f "$TUNNEL_PID_FILE" ]; then
        PID=$(cat "$TUNNEL_PID_FILE")
        log "Stopping tunnel process (PID: $PID)..."
        kill "$PID" 2>/dev/null || true
        rm -f "$TUNNEL_PID_FILE"
        success "Tunnel stopped"
    fi
}

# Function to send notification (supports ntfy and Discord)
send_notification() {
    local title="$1"
    local message="$2"
    
    # Try ntfy if configured
    if [ -n "$NTFY_URL" ] && [ -n "$NTFY_TOPIC" ]; then
        local ntfy_endpoint="$NTFY_URL/$NTFY_TOPIC"
        if [ -n "$NTFY_TOKEN" ]; then
            curl -sf -X POST "$ntfy_endpoint" \
                -H "Authorization: Bearer $NTFY_TOKEN" \
                -H "Title: $title" \
                -d "$message" > /dev/null 2>&1 || true
        else
            curl -sf -X POST "$ntfy_endpoint" \
                -H "Title: $title" \
                -d "$message" > /dev/null 2>&1 || true
        fi
    fi
    
    # Try Discord if configured
    if [ -n "$DISCORD_WEBHOOK_URL" ]; then
        curl -sf -X POST "$DISCORD_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"content\": \"**$title**\n$message\"}" > /dev/null 2>&1 || true
    fi
}

# Function to monitor tunnel
monitor_tunnel() {
    log "Starting tunnel monitor (checking every ${CHECK_INTERVAL}s)..."
    
    local consecutive_failures=0
    local last_url=""
    
    while true; do
        # Check if process is running
        if ! is_tunnel_running; then
            error "Tunnel process is not running!"
            consecutive_failures=$((consecutive_failures + 1))
            
            if [ $consecutive_failures -ge 3 ]; then
                error "Tunnel has failed 3 times consecutively. Restarting..."
                send_notification "🚨 Tunnel Crashed" "Tunnel process crashed. Attempting restart..."
                
                if start_tunnel; then
                    consecutive_failures=0
                    success "Tunnel restarted successfully"
                else
                    error "Failed to restart tunnel. Will retry in ${CHECK_INTERVAL}s..."
                fi
            else
                warning "Tunnel failure $consecutive_failures/3. Will check again in ${CHECK_INTERVAL}s..."
            fi
        else
            # Process is running, check if URL is accessible
            local current_url=$(get_tunnel_url)
            
            if [ -n "$current_url" ]; then
                # Check if URL changed
                if [ "$current_url" != "$last_url" ]; then
                    log "Detected new tunnel URL: $current_url"
                    echo "$current_url" > "$TUNNEL_URL_FILE"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] URL changed: $current_url" >> "$TUNNEL_HISTORY_FILE"
                    send_notification "🔄 Tunnel URL Changed" "$current_url"
                    last_url="$current_url"
                fi
                
                # Verify accessibility
                if is_tunnel_accessible "$current_url"; then
                    # Reset failure counter on success
                    if [ $consecutive_failures -gt 0 ]; then
                        success "Tunnel recovered and is accessible"
                        consecutive_failures=0
                    fi
                else
                    warning "Tunnel URL exists but is not accessible"
                    consecutive_failures=$((consecutive_failures + 1))
                fi
            else
                warning "No tunnel URL found in log"
                consecutive_failures=$((consecutive_failures + 1))
            fi
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

# Handle script termination
cleanup() {
    log "Received termination signal. Cleaning up..."
    stop_tunnel
    exit 0
}

trap cleanup SIGINT SIGTERM

# Main script
main() {
    log "Cloudflare Tunnel Monitor v1.0"
    log "================================"
    
    # Check if cloudflared is installed
    if ! command -v cloudflared &> /dev/null; then
        error "cloudflared is not installed!"
        error "Install it from: https://github.com/cloudflare/cloudflared/releases"
        exit 1
    fi
    
    # Check if tunnel is already running
    if is_tunnel_running; then
        log "Tunnel is already running"
        CURRENT_URL=$(get_tunnel_url)
        if [ -n "$CURRENT_URL" ]; then
            log "Current URL: $CURRENT_URL"
        fi
    else
        # Start tunnel for the first time
        if ! start_tunnel; then
            error "Failed to start tunnel"
            exit 1
        fi
    fi
    
    # Start monitoring
    monitor_tunnel
}

# Run main function
main
