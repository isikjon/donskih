#!/usr/bin/env bash
# Деплой только бэкенда на сервер. Запуск: из корня проекта или scripts/
# Использует SSH-хост donskih (настрой в ~/.ssh/config).

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_SRC="$REPO_ROOT/backend"
SSH_HOST="${DEPLOY_SSH_HOST:-donskih}"
REMOTE_PATH="${DEPLOY_BACKEND_PATH:-/opt/donskih-api}"

echo "=== Deploy backend to $SSH_HOST:$REMOTE_PATH ==="
rsync -avz \
  --exclude '.env' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude '.pytest_cache' \
  "$BACKEND_SRC/" "$SSH_HOST:$REMOTE_PATH/"

echo "=== Rebuild and restart on server ==="
ssh "$SSH_HOST" "cd $REMOTE_PATH && docker compose up -d --build"
echo "Done."
