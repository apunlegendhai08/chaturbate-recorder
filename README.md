# Chaturbate DVR

Automated Chaturbate stream recorder with a web dashboard, HLS capture, Cloudflare bypass, multi-host video uploads, and thumbnail previews.

Based on [teacat/chaturbate-dvr](https://github.com/teacat/chaturbate-dvr), extended for Docker deployment, GitHub Actions 24/7 recording, and upload integrations.

## Features

- **Web UI** — Add channels, pause/resume, live status via Server-Sent Events
- **HLS recording** — Classic `.ts` and LL-HLS `.m4s` (separate audio/video)
- **Cloudflare bypass** — Byparr / FlareSolverr with cookie refresher
- **Segment splitting** — Optional max duration / file size per part
- **ffmpeg** — Mux, compress to `.mkv`, thumbnails and hover sprites
- **Uploads** — GoFile, Streamtape, Voe.sx, SendCM, Byse, TurboViPlay (parallel)
- **Thumbnails** — Pixhost → Catbox → Freeimage fallback chain
- **CI** — GitHub Actions workflow for scheduled recording and `database/recordings.json` sync

## Quick start (Docker)

1. Copy environment template and fill in API keys:

   ```bash
   cp .env.example .env
   ```

2. Start the stack:

   ```bash
   docker compose up -d --build
   ```

3. Open the dashboard: **http://localhost:8080**

4. Add channels in the UI (saved to `conf/channels.json`).

### Docker services

| Service | Port | Role |
|---------|------|------|
| `chaturbate-dvr` | 8080 | Recorder + web UI |
| `byparr-lb` | 8191 | Cloudflare bypass (load-balanced Byparr) |
| `cookie-refresher` | — | Refreshes CF cookies via Byparr |
| `uploader` | — | Python daemon for backlog uploads |

Volumes: `./videos`, `./conf`, `./database`.

## Local development

**Requirements:** Go 1.23+, ffmpeg, Node.js (for Tailwind CSS build)

```bash
# Build CSS (embedded in Go binary via Docker; optional locally)
npm ci
npm run build:css

# Run web UI mode (loads conf/channels.json)
go run . --port 8080

# Single channel CLI mode
go run . --username some_model --port 8080
```

### Useful flags

| Flag | Description |
|------|-------------|
| `--port` | Web UI port (default `8080`) |
| `--cookies` / `COOKIES` | Browser cookies for Chaturbate requests |
| `--user-agent` / `USER_AGENT` | Custom User-Agent |
| `--admin-username` / `--admin-password` | Optional HTTP basic auth |
| `--compress` | ffmpeg compress to `.mkv` after recording |
| `--output-dir` | Move finished files to another directory |
| `--interval` | Minutes between retries when offline |

Set `FLARESOLVERR_URL` (e.g. `http://localhost:8191/v1`) when running without Docker’s Byparr stack.

## Configuration

| Path | Purpose |
|------|---------|
| `conf/channels.json` | Channel list (usernames, resolution, filename pattern) |
| `database/recordings.json` | Upload links, thumbnails, embed URLs (tracked in git) |
| `videos/` | Recorded files (not committed) |
| `.env` | API keys for uploads and CI (not committed) |

### Upload API keys (optional)

Configure in `.env` or docker-compose / CLI:

- `STREAMTAPE_LOGIN`, `STREAMTAPE_API_KEY`
- `VOESX_API_KEY`
- `SENDCM_API_KEY`
- `GOFILE_API_KEY`
- `BYSE_API_KEY`
- `TURBOVIPLAY_API_KEY`

### Thumbnail hosting

Preview images use a fallback chain (see `uploader/image_upload.go`):

1. **Pixhost** — NSFW-friendly image API  
2. **Catbox** — Permanent file hosting  
3. **Freeimage** — Last resort  

URLs are stored in sidecar files (`.thumb`, `.sprite`) and in `database/recordings.json`.

## GitHub Actions

Workflow: [`.github/workflows/recorder.yml`](.github/workflows/recorder.yml)

- Runs `docker compose` on a schedule or manual dispatch (1–5 hours)
- Commits updated `database/recordings.json` back to the repo
- Requires repository secrets from `.env.example` (Streamtape, Voe, SendCM, Supabase, etc.)

## Project layout

```
main.go              CLI entry
manager/             Channel registry, SSE, config persistence
channel/             Recording, files, thumbnails, uploads
chaturbate/          Stream discovery, m3u8, edge fallback
internal/            HTTP client, FlareSolverr, Chaturbate API
router/              Gin web UI + embedded templates
uploader/            Video and image upload clients
docker-compose.yml   Full production stack
scripts/             Diagnostics, cookie refresh, Python uploader
```

## Scripts

| Script | Use |
|--------|-----|
| `scripts/cookie-refresher.sh` | Refresh Cloudflare cookies (Docker) |
| `scripts/uploader_daemon.py` | Upload completed videos from disk |
| `scripts/diagnose-recording.ps1` | Local recording troubleshooting |
| `scripts/fix-cloudflare-local.ps1` | Local Byparr / cookie setup |

## Legal

Only record content you are permitted to record. You are responsible for compliance with platform terms of service and applicable law. This software is provided as-is for personal automation.

## Credits

- Upstream: [teacat/chaturbate-dvr](https://github.com/teacat/chaturbate-dvr)
- Cloudflare bypass: [Byparr](https://github.com/ThePhaseless/Byparr)
