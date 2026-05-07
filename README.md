# gclawbot

AI agent bot running OpenClaw + Ollama (qwen2.5:7b) on GPU, connected to Telegram.

## Requirements

- NVIDIA GPU (4070 Ti or better, 12GB+ VRAM)
- Docker Compose v2
- `nvidia-container-toolkit` ([install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html))

## First-Time Setup

### 1. Prepare environment

```bash
cp .env.example .env
echo "OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)" >> .env
```

### 2. Install nvidia-container-toolkit (if not already installed)

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### 3. Start Ollama and pull model (~5GB, one-time)

```bash
docker compose up -d ollama
docker compose exec ollama ollama pull qwen2.5:7b
```

### 4. Start OpenClaw

```bash
docker compose up -d
```

### 5. Enable Telegram plugin

```bash
docker compose exec openclaw openclaw plugins enable telegram
docker compose restart openclaw
```

### 6. Configure Ollama as provider

```bash
docker compose exec openclaw openclaw config set models.providers.ollama '{"baseUrl":"http://ollama:11434","apiKey":"ollama-local","api":"ollama","models":[{"id":"qwen2.5:7b","name":"qwen2.5:7b"}]}'
docker compose exec openclaw openclaw config set agents.defaults.model "ollama/qwen2.5:7b"
docker compose restart openclaw
```

### 7. Create Telegram bot

1. Open Telegram → search `@BotFather` → send `/newbot`
2. Follow prompts to get a bot token (format: `1234567890:ABCdef...`)

### 8. Add Telegram bot to OpenClaw

```bash
docker compose exec openclaw openclaw channels add --channel telegram --token "YOUR_BOT_TOKEN"
docker compose restart openclaw
```

### 9. Pair your Telegram account

1. Open Telegram → search your bot username → send `/start`
2. Bot replies with a pairing code — approve it:

```bash
docker compose exec openclaw openclaw pairing list telegram
docker compose exec openclaw openclaw pairing approve telegram <CODE>
```

The approval output shows your numeric Telegram user ID.

### 10. Lock bot to your account only

```bash
docker compose exec openclaw openclaw config set channels.telegram.dmPolicy allowlist
docker compose exec openclaw openclaw config set channels.telegram.allowFrom '["YOUR_NUMERIC_ID"]'
docker compose restart openclaw
```

Send a message to your bot — it should respond using qwen2.5:7b.

---

## Usage

- **Control UI:** http://127.0.0.1:18789/
- **Logs:** `docker compose logs -f`
- **Stop:** `docker compose down`
- **Restart:** `docker compose restart`

## Architecture

See `docs/superpowers/specs/2026-05-06-openclaw-docker-ollama-design.md` for full design.
