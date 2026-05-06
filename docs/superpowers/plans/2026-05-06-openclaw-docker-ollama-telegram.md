# OpenClaw Docker + Ollama + Telegram Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up OpenClaw AI agents platform in Docker with Ollama (qwen2.5:7b on 4070 Ti GPU), connected to a private Telegram bot.

**Architecture:** Two Docker Compose services (`ollama` + `openclaw`) on a shared bridge network. Ollama exposes port 11434 internally only. OpenClaw depends on Ollama healthcheck before starting. All state persisted in named volumes.

**Tech Stack:** Docker Compose v2, `ollama/ollama` image, `ghcr.io/openclaw/openclaw:latest`, NVIDIA container runtime, qwen2.5:7b, Telegram Bot API.

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `.gitignore` | Create | Exclude `.env` and secrets from git |
| `.env.example` | Create | Template for required env vars |
| `.env` | Create (not committed) | Actual secrets + config |
| `docker-compose.yml` | Create | Defines ollama + openclaw services |
| `openclaw.json` | Create | OpenClaw channel + model config |
| `README.md` | Modify | Setup and usage instructions |

---

## Task 1: Secrets protection

**Files:**
- Create: `.gitignore`
- Create: `.env.example`

- [ ] **Step 1: Create .gitignore**

```
.env
openclaw.json
```

> `openclaw.json` contains the Telegram bot token — never commit it.

- [ ] **Step 2: Create .env.example**

```
OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest
OPENCLAW_HOME_VOLUME=1
OLLAMA_BASE_URL=http://ollama:11434
# OPENCLAW_GATEWAY_TOKEN=  <-- filled by setup script on first run
```

- [ ] **Step 3: Create .env from example**

```bash
cp .env.example .env
```

- [ ] **Step 4: Verify .gitignore works**

```bash
git status
```

Expected: `.env` and `openclaw.json` do NOT appear in untracked files. `.gitignore` and `.env.example` DO appear.

- [ ] **Step 5: Commit**

```bash
git add .gitignore .env.example
git commit -m "chore: add gitignore and env template"
```

---

## Task 2: docker-compose.yml

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 1: Verify Docker Compose v2 installed**

```bash
docker compose version
```

Expected: `Docker Compose version v2.x.x`

- [ ] **Step 2: Create docker-compose.yml**

```yaml
services:
  ollama:
    image: ollama/ollama
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
    volumes:
      - ollama_data:/root/.ollama
    networks:
      - openclaw_net
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "ollama", "list"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s

  openclaw:
    image: ${OPENCLAW_IMAGE:-ghcr.io/openclaw/openclaw:latest}
    depends_on:
      ollama:
        condition: service_healthy
    ports:
      - "127.0.0.1:18789:18789"
    volumes:
      - openclaw_home:/home/node
      - ./openclaw.json:/home/node/openclaw.json:ro
    environment:
      - OPENCLAW_HOME_VOLUME=1
      - OLLAMA_BASE_URL=${OLLAMA_BASE_URL:-http://ollama:11434}
    networks:
      - openclaw_net
    restart: unless-stopped

volumes:
  ollama_data:
  openclaw_home:

networks:
  openclaw_net:
    driver: bridge
```

- [ ] **Step 3: Validate compose file**

```bash
docker compose config
```

Expected: full resolved YAML printed with no errors.

- [ ] **Step 4: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: add docker-compose with ollama and openclaw services"
```

---

## Task 3: Host prerequisites — NVIDIA container toolkit

> Run these on the host machine. Only needed once. Skip if already installed.

**Files:** none (host system config)

- [ ] **Step 1: Check if already installed**

```bash
nvidia-ctk --version
```

If this prints a version, skip to Step 5.

- [ ] **Step 2: Install nvidia-container-toolkit**

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
```

- [ ] **Step 3: Configure Docker runtime**

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

- [ ] **Step 4: Verify GPU access in Docker**

```bash
docker run --rm --runtime=nvidia --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi
```

Expected: `nvidia-smi` output showing your 4070 Ti.

- [ ] **Step 5: Verify Ollama can see GPU**

```bash
docker compose up -d ollama
docker compose exec ollama ollama run qwen2.5:7b "say hello" 2>/dev/null | head -5
```

Wait ~30s for Ollama to start. Expected: some text output (model not yet pulled — will error, that's fine — just confirms runtime works).

---

## Task 4: Pull qwen2.5:7b model

**Files:** none

- [ ] **Step 1: Start Ollama service**

```bash
docker compose up -d ollama
```

- [ ] **Step 2: Wait for Ollama healthy**

```bash
docker compose ps ollama
```

Expected: `Status` column shows `healthy`. May take 30-60s on first boot.

- [ ] **Step 3: Pull the model (~5GB, one-time)**

```bash
docker compose exec ollama ollama pull qwen2.5:7b
```

Expected: Progress bar → `success`. Takes 2-10 min depending on connection.

- [ ] **Step 4: Verify model loaded**

```bash
docker compose exec ollama ollama list
```

Expected: `qwen2.5:7b` appears in list.

- [ ] **Step 5: Test inference on GPU**

```bash
docker compose exec ollama ollama run qwen2.5:7b "reply with only: ok"
```

Expected: `ok` (or similar). Check GPU usage in another terminal with `nvidia-smi` while this runs — should show utilisation > 0%.

---

## Task 5: Create openclaw.json config template

**Files:**
- Create: `openclaw.json`

> This file is gitignored. Contains Telegram bot token (filled in Task 6).

- [ ] **Step 1: Create openclaw.json**

```json5
{
  channels: {
    telegram: {
      token: "REPLACE_WITH_BOTFATHER_TOKEN",
      dmPolicy: "allowlist",
      allowFrom: ["REPLACE_WITH_YOUR_TELEGRAM_USER_ID"],
    },
  },
  agents: {
    defaults: {
      model: "ollama/qwen2.5:7b",
    },
  },
}
```

- [ ] **Step 2: Verify file is gitignored**

```bash
git status
```

Expected: `openclaw.json` does NOT appear in untracked files.

---

## Task 6: OpenClaw first-run setup

**Files:** `.env` (modified by setup script), `scripts/` (fetched from OpenClaw)

- [ ] **Step 1: Download OpenClaw setup scripts**

The setup script lives in OpenClaw's repo. Fetch it without cloning the full repo:

```bash
mkdir -p scripts/docker
curl -fsSL https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/docker/setup.sh \
  -o scripts/docker/setup.sh
chmod +x scripts/docker/setup.sh
```

If the URL fails (repo may be private or path may differ), check https://docs.openclaw.ai for the correct scripts location.

Add to `.gitignore`:
```
scripts/
```

- [ ] **Step 2: Run OpenClaw setup script**

```bash
OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest ./scripts/docker/setup.sh
```

Script will prompt interactively:
- LLM provider URL → enter `http://ollama:11434`
- Any API key prompts → leave blank (Ollama needs no key)
- Script writes `OPENCLAW_GATEWAY_TOKEN` to `.env`

- [ ] **Step 3: Verify gateway token written**

```bash
grep OPENCLAW_GATEWAY_TOKEN .env
```

Expected: line with a token value present.

- [ ] **Step 4: Bring up full stack**

```bash
docker compose up -d
```

- [ ] **Step 5: Verify both services healthy**

```bash
docker compose ps
```

Expected: both `ollama` and `openclaw` show as running/healthy.

- [ ] **Step 6: Verify Control UI accessible**

```bash
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18789/
```

Expected: `200` or `301`.

- [ ] **Step 7: Get dashboard link**

```bash
docker compose run --rm openclaw-cli dashboard --no-open
```

Copy the URL printed. Open it in browser. Paste the shared secret from `.env` (`OPENCLAW_GATEWAY_TOKEN`) into Settings when prompted.

---

## Task 7: Telegram bot setup

**Files:** `openclaw.json` (update with real token + user ID)

- [ ] **Step 1: Create bot via BotFather**

Open Telegram → search `@BotFather` → send `/newbot` → follow prompts → copy the token (format: `1234567890:ABCdef...`).

- [ ] **Step 2: Update openclaw.json with token**

Replace `REPLACE_WITH_BOTFATHER_TOKEN` in `openclaw.json` with your actual token.

- [ ] **Step 3: Login Telegram channel**

```bash
docker compose run --rm openclaw-cli channels login --channel telegram
```

Paste bot token when prompted. Expected: `Connected` or similar success message.

- [ ] **Step 4: Find your Telegram user ID**

Send any message to your new bot in Telegram, then:

```bash
docker compose logs openclaw --follow
```

Look for `from.id` field in log output. Copy that number.

Stop log tail with `Ctrl+C`.

- [ ] **Step 5: Update openclaw.json allowlist**

Replace `REPLACE_WITH_YOUR_TELEGRAM_USER_ID` in `openclaw.json` with your numeric user ID (e.g. `123456789`).

- [ ] **Step 6: Restart OpenClaw to apply config**

```bash
docker compose restart openclaw
```

- [ ] **Step 7: Verify bot responds**

Send a message to your Telegram bot. Expected: reply from qwen2.5:7b within ~5-15 seconds.

If no reply, check logs:

```bash
docker compose logs openclaw --tail=50
```

---

## Task 8: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace README content**

```markdown
# gclawbot

AI agent bot running OpenClaw + Ollama (qwen2.5:7b) on GPU, connected to Telegram.

## Requirements

- NVIDIA GPU (4070 Ti or better)
- Docker Compose v2
- `nvidia-container-toolkit` ([install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html))

## Setup

1. Copy env template:
   ```bash
   cp .env.example .env
   ```

2. Start Ollama and pull model:
   ```bash
   docker compose up -d ollama
   docker compose exec ollama ollama pull qwen2.5:7b
   ```

3. Run OpenClaw setup:
   ```bash
   OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest ./scripts/docker/setup.sh
   ```

4. Create `openclaw.json` from the template in `docs/superpowers/specs/` and fill in your Telegram bot token and user ID.

5. Login Telegram:
   ```bash
   docker compose run --rm openclaw-cli channels login --channel telegram
   ```

6. Start full stack:
   ```bash
   docker compose up -d
   ```

## Usage

- Control UI: http://127.0.0.1:18789/
- Logs: `docker compose logs -f`
- Stop: `docker compose down`

## Architecture

See `docs/superpowers/specs/2026-05-06-openclaw-docker-ollama-design.md`
```

- [ ] **Step 2: Commit everything**

```bash
git add README.md
git commit -m "docs: update README with setup instructions"
```

---

## Verification Checklist

After completing all tasks, verify end-to-end:

- [ ] `docker compose ps` — both services running and healthy
- [ ] `nvidia-smi` — GPU utilisation spikes when sending a Telegram message
- [ ] Telegram message → bot reply within 15s
- [ ] `docker compose down && docker compose up -d` — stack recovers cleanly, model weights persist (no re-pull)
- [ ] Only your Telegram user ID can get replies (test with another account if available — should get no response)
