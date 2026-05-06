# OpenClaw Docker + Ollama + Telegram — Design Spec

**Date:** 2026-05-06
**Status:** Approved

## Goal

Run OpenClaw AI agents platform in Docker with a local Ollama model (qwen2.5:7b) on GPU, connected to Telegram via official Bot API.

## Architecture

Two-service Docker Compose stack on a single host.

```
Telegram Bot API
      │
      ▼
OpenClaw container  ──────────────────→  Ollama container
(ghcr.io/openclaw/openclaw:latest)       (ollama/ollama + NVIDIA runtime)
  port 18789 (Control UI)                  qwen2.5:7b on 4070 Ti
  http://ollama:11434 (internal)           port 11434 (internal only)
```

Both services share `openclaw_net` bridge network. Ollama port is not exposed to host.

## Host Requirements

- NVIDIA 4070 Ti (12GB VRAM) — qwen2.5:7b fits fully on GPU
- 78GB RAM — headroom for OS + compose overhead
- `nvidia-container-toolkit` installed and Docker NVIDIA runtime configured
- Docker Compose v2

## Services

### ollama

- Image: `ollama/ollama` (official)
- Runtime: `nvidia`
- GPU device: all (or device index 0)
- Volume: `ollama_data:/root/.ollama` — persists model weights (~5GB one-time pull)
- Healthcheck: `ollama list` returns healthy
- Restart: `unless-stopped`
- Network: `openclaw_net`
- Model pulled via one-off command after first boot: `docker compose run --rm ollama ollama pull qwen2.5:7b`

### openclaw

- Image: `ghcr.io/openclaw/openclaw:latest`
- Depends on: `ollama` (condition: service_healthy)
- Volume: `openclaw_home` (via `OPENCLAW_HOME_VOLUME=1`) — persists config, sessions, plugins
- Ports: `18789:18789` (Control UI, localhost only)
- Restart: `unless-stopped`
- Network: `openclaw_net`
- Env: loaded from `.env`

## Configuration

### .env

```
OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest
OPENCLAW_HOME_VOLUME=1
OLLAMA_BASE_URL=http://ollama:11434
```

Gateway token added by OpenClaw setup script on first run.

### openclaw.json

```json5
{
  channels: {
    telegram: {
      token: "<BOTFATHER_TOKEN>",
    },
  },
  agents: {
    defaults: {
      model: "ollama/qwen2.5:7b",
    },
  },
}
```

## Onboarding Steps

1. Install `nvidia-container-toolkit` on host, restart Docker daemon
2. Clone repo, `cd gclawbot`
3. `docker compose up -d ollama` — starts Ollama
4. `docker compose run --rm ollama ollama pull qwen2.5:7b` — pulls model (~5GB, one-time)
5. Run OpenClaw setup: `OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest ./scripts/docker/setup.sh`
   - Script prompts for LLM provider → point to `http://ollama:11434`
   - Gateway token written to `.env`
6. Create Telegram bot via @BotFather → copy token
7. `docker compose run --rm openclaw-cli channels login --channel telegram` → paste token
8. Access Control UI: `http://127.0.0.1:18789/`
9. Paste shared secret in Settings to activate dashboard

## Data Flow

1. User sends message to Telegram bot
2. OpenClaw receives via Telegram Bot API (polling or webhook)
3. Agent processes message, sends inference request to `http://ollama:11434`
4. Ollama runs qwen2.5:7b on 4070 Ti, returns completion
5. OpenClaw sends response back to Telegram

## Volumes

| Volume | Purpose |
|--------|---------|
| `ollama_data` | Model weights — survives container restarts |
| `openclaw_home` | OpenClaw config, sessions, plugins, pairing state |

## Error Handling

- OpenClaw waits for Ollama healthcheck before starting (`depends_on: condition: service_healthy`)
- Both services restart automatically (`unless-stopped`)
- If GPU unavailable, Ollama falls back to CPU (slower but functional)

## Out of Scope

- Sandbox mode (can add later via `OPENCLAW_SANDBOX=1`)
- Multiple agents or models
- Webhook mode for Telegram (polling sufficient for personal use)
- Authentication beyond Telegram bot token
