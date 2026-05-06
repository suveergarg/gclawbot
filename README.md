# gclawbot

AI agent bot running OpenClaw + Ollama (qwen2.5:7b) on GPU, connected to Telegram.

## Requirements

- NVIDIA GPU (4070 Ti or better, 12GB+ VRAM)
- Docker Compose v2
- `nvidia-container-toolkit` ([install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html))

## Setup

1. Copy env template:
   ```bash
   cp .env.example .env
   ```

2. Install nvidia-container-toolkit (if not already installed):
   ```bash
   curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
     && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
       sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
       sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
   sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
   ```

3. Start Ollama and pull model (~5GB, one-time):
   ```bash
   docker compose up -d ollama
   docker compose exec ollama ollama pull qwen2.5:7b
   ```

4. Get OpenClaw setup scripts and run first-time setup:
   ```bash
   mkdir -p scripts/docker
   curl -fsSL https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/docker/setup.sh \
     -o scripts/docker/setup.sh
   chmod +x scripts/docker/setup.sh
   OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest ./scripts/docker/setup.sh
   ```
   When prompted for LLM provider URL, enter: `http://ollama:11434`

5. Create `openclaw.json` (gitignored — contains secrets):
   ```bash
   # Already created as a template — fill in your values:
   # - channels.telegram.token: get from @BotFather on Telegram
   # - channels.telegram.allowFrom: your Telegram numeric user ID
   ```

6. Login Telegram channel:
   ```bash
   docker compose run --rm openclaw-cli channels login --channel telegram
   ```

7. Find your Telegram user ID:
   ```bash
   # Send any message to your bot, then:
   docker compose logs openclaw --follow
   # Look for "from.id" in the log output
   ```
   Update `openclaw.json` with your numeric user ID, then restart:
   ```bash
   docker compose restart openclaw
   ```

8. Start full stack:
   ```bash
   docker compose up -d
   ```

## Usage

- **Control UI:** http://127.0.0.1:18789/
- **Logs:** `docker compose logs -f`
- **Stop:** `docker compose down`
- **Restart:** `docker compose restart`

## Architecture

See `docs/superpowers/specs/2026-05-06-openclaw-docker-ollama-design.md` for full design.
