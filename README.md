# gclawbot

AI agent bot running OpenClaw + Ollama on GPU, connected to Signal.

**Models:**
- `deepseek-r1:14b` — default for conversations (16k context)
- `qwen2.5-coder:14b` — used by github-issue-fixer skill (16k context)

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

### 3. Start Ollama and pull models (~18GB total, one-time)

```bash
docker compose up -d ollama

# Pull base models
docker compose exec ollama ollama pull deepseek-r1:14b
docker compose exec ollama ollama pull qwen2.5-coder:14b

# Create 16k context variants
docker compose exec ollama bash -c 'printf "FROM deepseek-r1:14b\nPARAMETER num_ctx 16384\n" > /tmp/Mf && ollama create deepseek-r1:14b-16k -f /tmp/Mf'
docker compose exec ollama bash -c 'printf "FROM qwen2.5-coder:14b\nPARAMETER num_ctx 16384\n" > /tmp/Mf && ollama create qwen2.5-coder:14b-16k -f /tmp/Mf'
```

### 4. Start OpenClaw

```bash
docker compose up -d
```

### 5. Enable Signal plugin

```bash
docker compose exec openclaw openclaw plugins enable signal
docker compose restart openclaw
```

### 6. Configure Ollama as provider

```bash
docker compose exec openclaw openclaw config set models.providers.ollama '{"baseUrl":"http://ollama:11434","apiKey":"ollama-local","api":"ollama","models":[{"id":"deepseek-r1:14b-16k","name":"DeepSeek R1 14b"},{"id":"qwen2.5-coder:14b-16k","name":"Qwen2.5 Coder 14b"}]}'
docker compose exec openclaw openclaw config set agents.defaults.model "ollama/deepseek-r1:14b-16k"
docker compose restart openclaw
```

### 7. Link signal-cli to your Signal account

signal-cli runs as a linked device on your existing Signal account.

```bash
# Get the QR code link to scan with your Signal app
docker compose exec signal-cli signal-cli --config /home/.local/share/signal-cli link -n "gclawbot"
```

This prints a `sgnl://linkdevice?...` URI. Convert it to a QR code:

```bash
# On your machine (not in container), install qrencode if needed:
sudo apt install qrencode
# Then:
qrencode -t ansiutf8 'sgnl://linkdevice?...'
```

Scan the QR code from Signal on your phone: **Settings → Linked Devices → Link New Device**.

### 8. Add Signal channel to OpenClaw

```bash
docker compose exec openclaw openclaw channels add --channel signal \
  --signal-number "+1XXXXXXXXXX" \
  --http-host signal-cli \
  --http-port 8080
docker compose restart openclaw
```

### 9. Pair your Signal account

Send any message to yourself (the linked number) — OpenClaw intercepts it and replies with a pairing code:

```bash
docker compose exec openclaw openclaw pairing list signal
docker compose exec openclaw openclaw pairing approve signal <CODE>
```

### 10. Lock to your account only

```bash
docker compose exec openclaw openclaw config set channels.signal.dmPolicy allowlist
docker compose exec openclaw openclaw config set channels.signal.allowFrom '["+1XXXXXXXXXX"]'
docker compose restart openclaw
```

Send a message to yourself on Signal — OpenClaw responds using deepseek-r1:14b.

---

## GitHub Integration (for github-issue-fixer skill)

### 1. Enable openshell plugin

```bash
docker compose exec openclaw openclaw plugins enable openshell
docker compose restart openclaw
```

### 2. Authenticate gh CLI (one-time, interactive)

```bash
docker compose exec -it openclaw gh auth login
```

Select: `GitHub.com` → `HTTPS` → `Login with a web browser` → follow prompts.

Token stored in `./data/openclaw/.config/gh/` — persists across restarts. Re-run after fresh clone.

### 3. Configure git identity

```bash
docker compose exec openclaw git config --global user.name "Your Name"
docker compose exec openclaw git config --global user.email "your@email.com"
```

### 4. Configure monitored repositories

Edit `skills/github-issue-fixer/SKILL.md` — update the repositories list under "Configured repositories".

### 5. Register cron job (nightly runs)

```bash
./scripts/setup-cron.sh
```

### 6. Verify

```bash
docker compose exec openclaw gh auth status
docker compose exec openclaw gh repo list --limit 3
docker compose exec openclaw openclaw skills check
```

---

## Control UI

- **URL:** http://127.0.0.1:18789/
- **Token:** stored in `.env` as `OPENCLAW_GATEWAY_TOKEN`

## Usage

- **Logs:** `docker compose logs -f`
- **Stop:** `docker compose down`
- **Restart:** `docker compose restart`

## Architecture

See `docs/superpowers/specs/2026-05-06-openclaw-docker-ollama-design.md` for full design.
