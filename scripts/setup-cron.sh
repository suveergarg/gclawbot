#!/usr/bin/env bash
# Register OpenClaw cron jobs.
# Run after first-time setup: ./scripts/setup-cron.sh
# Safe to re-run — removes existing jobs before re-adding.
set -euo pipefail

COMPOSE="docker compose -f $(dirname "$0")/../docker-compose.yml"
CLI="$COMPOSE exec openclaw openclaw"

echo "Removing existing cron jobs..."
for job in nightly-issue-fixer; do
  $CLI cron rm "$job" 2>/dev/null || true
done

echo "Adding cron jobs..."

# Nightly GitHub issue fixer — runs at 2am, reports via Telegram
$CLI cron add \
  --name "nightly-issue-fixer" \
  --cron "0 2 * * *" \
  --message "Run the github-issue-fixer skill. Fix one open issue per configured repo. When done, send me a summary of all PRs opened tonight with their URLs and issue titles." \
  --channel telegram \
  --to 7404130264 \
  --announce \
  --timeout-seconds 14400 \
  --description "Nightly GitHub issue fixer — runs 2am, reports PRs via Telegram"

echo ""
echo "Done. Current cron jobs:"
$CLI cron list
