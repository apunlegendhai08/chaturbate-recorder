#!/bin/bash

# Script to get the current tunnel URL from various sources
# Priority: 1. Local file, 2. Supabase, 3. Tunnel log

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TUNNEL_URL_FILE="tunnel_url.txt"
TUNNEL_LOG="tunnel.log"

echo "🔍 Searching for current tunnel URL..."
echo ""

# Method 1: Check local file
if [ -f "$TUNNEL_URL_FILE" ]; then
    URL=$(cat "$TUNNEL_URL_FILE")
    if [ -n "$URL" ]; then
        echo -e "${GREEN}✓ Found in local file:${NC}"
        echo "  $URL"
        echo ""
        
        # Verify it's accessible
        if curl -sf --max-time 5 "$URL" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Tunnel is accessible${NC}"
        else
            echo -e "${YELLOW}⚠ Tunnel URL exists but may not be accessible${NC}"
        fi
        exit 0
    fi
fi

# Method 2: Check Supabase
if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_API_KEY" ]; then
    echo "Checking Supabase..."
    URL=$(curl -sf "$SUPABASE_URL/rest/v1/current_tunnel?select=url" \
        -H "apikey: $SUPABASE_API_KEY" \
        -H "Authorization: Bearer $SUPABASE_API_KEY" | \
        grep -oP '"url":"[^"]+' | cut -d'"' -f4)
    
    if [ -n "$URL" ]; then
        echo -e "${GREEN}✓ Found in Supabase:${NC}"
        echo "  $URL"
        echo ""
        
        # Save to local file for faster access next time
        echo "$URL" > "$TUNNEL_URL_FILE"
        
        # Verify it's accessible
        if curl -sf --max-time 5 "$URL" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Tunnel is accessible${NC}"
        else
            echo -e "${YELLOW}⚠ Tunnel URL exists but may not be accessible${NC}"
        fi
        exit 0
    fi
fi

# Method 3: Check tunnel log
if [ -f "$TUNNEL_LOG" ]; then
    echo "Checking tunnel log..."
    URL=$(grep -oP 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" | tail -1)
    
    if [ -n "$URL" ]; then
        echo -e "${GREEN}✓ Found in tunnel log:${NC}"
        echo "  $URL"
        echo ""
        
        # Save to local file
        echo "$URL" > "$TUNNEL_URL_FILE"
        
        # Verify it's accessible
        if curl -sf --max-time 5 "$URL" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Tunnel is accessible${NC}"
        else
            echo -e "${YELLOW}⚠ Tunnel URL exists but may not be accessible${NC}"
        fi
        exit 0
    fi
fi

# Not found
echo -e "${RED}✗ No tunnel URL found${NC}"
echo ""
echo "Possible reasons:"
echo "  • Tunnel is not running"
echo "  • Tunnel hasn't started yet"
echo "  • Tunnel log file doesn't exist"
echo ""
echo "To start the tunnel monitor:"
echo "  bash scripts/monitor-tunnel.sh"
exit 1
