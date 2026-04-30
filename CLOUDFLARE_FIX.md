# Cloudflare Bypass Solution

## Problem
All channels are being blocked by Cloudflare with HTTP 403 errors. The EC2 IP address is flagged/rate-limited by Chaturbate's Cloudflare protection.

## Root Cause
- EC2 datacenter IPs have low reputation scores with Cloudflare
- 28 channels hitting simultaneously creates bot-like traffic patterns
- FlareSolverr alone cannot bypass aggressive Cloudflare protection without residential proxies

## Solution: Residential Proxies

According to industry research, **residential proxies achieve 95-99% success rate** for bypassing Cloudflare, compared to datacenter IPs which are frequently blocked.

### Why Residential Proxies Work
1. **Real IP addresses** from ISPs (Comcast, Verizon, etc.) - not datacenter IPs
2. **High trust scores** with Cloudflare
3. **Rotating IPs** prevent pattern detection
4. **Geographic diversity** appears more natural

### Implementation Steps

#### Option 1: Free Trial (Recommended for Testing)
Try these providers with free trials:
- **BrightData**: $5 credit, 7-day trial
- **Smartproxy**: $5 credit, 3-day trial  
- **Oxylabs**: 7-day free trial

#### Option 2: Budget-Friendly Providers
- **Proxy-Cheap**: ~$3/GB residential
- **Webshare**: ~$2.99/GB residential
- **IPRoyal**: ~$1.75/GB residential

### Configuration

1. **Get proxy credentials** from your provider
2. **Create `.env` file** in project root:
```bash
PROXY_URL=http://proxy.provider.com:8080
PROXY_USERNAME=your_username
PROXY_PASSWORD=your_password
```

3. **Deploy to EC2**:
```bash
# Upload .env file
scp -i aws-secrets/aws-key.pem .env ubuntu@54.210.37.19:/home/ubuntu/goondvr/

# Restart containers
ssh -i aws-secrets/aws-key.pem ubuntu@54.210.37.19 "cd /home/ubuntu/goondvr && sudo docker compose down && sudo docker compose up -d"
```

### Expected Results
- ✅ **95-99% success rate** on Cloudflare bypass
- ✅ All 28 channels recording simultaneously
- ✅ No more HTTP 403 errors
- ✅ Stable long-term recording

### Cost Estimation
For 28 channels checking every minute:
- **Bandwidth per check**: ~2MB (with browser)
- **Daily checks**: 28 channels × 1,440 minutes = 40,320 checks
- **Daily bandwidth**: ~80GB
- **Monthly bandwidth**: ~2.4TB
- **Monthly cost**: $200-400 (depending on provider)

### Alternative: Reduce Costs

If proxies are too expensive, consider:

1. **Reduce check frequency** (every 2-3 minutes instead of 1)
2. **Use fewer channels** (prioritize top performers)
3. **Hybrid approach**: Use proxies only for initial checks, direct IP for streaming
4. **Session persistence**: Reuse FlareSolverr sessions to reduce proxy usage

### Without Proxies (Current State)
- ❌ EC2 IP is flagged by Cloudflare
- ❌ All channels blocked with HTTP 403
- ❌ FlareSolverr cannot bypass alone
- ❌ No recordings happening

## Technical Details

### How FlareSolverr + Proxies Work Together
1. FlareSolverr launches Chrome browser
2. Browser connects through residential proxy
3. Cloudflare sees request from residential IP (high trust)
4. JavaScript challenges pass successfully
5. Valid `cf_clearance` cookies returned
6. Application uses cookies for subsequent requests

### Monitoring Success
Check logs for successful bypasses:
```bash
ssh -i aws-secrets/aws-key.pem ubuntu@54.210.37.19 "cd /home/ubuntu/goondvr && sudo docker compose logs recorder | grep 'stream type'"
```

If you see "stream type" messages, channels are recording successfully!

## References
- [How To Bypass Cloudflare in 2026](https://scrapeops.io/web-scraping-playbook/how-to-bypass-cloudflare/)
- [Residential Proxies for Cloudflare](https://brightdata.com/blog/proxy-101/how-to-bypass-an-ip-ban)
- [FlareSolverr Documentation](https://github.com/FlareSolverr/FlareSolverr)
