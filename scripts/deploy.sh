#!/usr/bin/env bash
set -e

# Настройки сервера (API и веб). Запускай с машины, где настроен SSH к серверу.
# Используем SSH-алиас из ~/.ssh/config (по умолчанию "donskih").
SSH_HOST="${DEPLOY_SSH_HOST:-donskih}"
BACKEND_PATH="${DEPLOY_BACKEND_PATH:-/opt/donskih-api}"
WEB_PATH="${DEPLOY_WEB_PATH:-/var/www/donskih-admin}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_SRC="$REPO_ROOT/backend"
WEB_SRC="$REPO_ROOT/build/web"

# Автоматически собираем Flutter Web с правильным base-href
echo "[0/4] Building Flutter Web..."
(cd "$REPO_ROOT" && flutter build web --base-href /admin/)

if [[ ! -d "$WEB_SRC" ]] || [[ ! -f "$WEB_SRC/index.html" ]]; then
  echo "Flutter build failed!"
  exit 1
fi

echo "=== Deploy to $SSH_HOST ==="
echo "  Backend -> $BACKEND_PATH"
echo "  Web     -> $WEB_PATH"
echo ""

# 1. Загрузка бэкенда (без .env и __pycache__)
echo "[1/4] Syncing backend..."
rsync -avz --delete \
  --exclude '.env' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude '.pytest_cache' \
  --exclude '.mypy_cache' \
  --exclude 'venv' \
  --exclude '.venv' \
  "$BACKEND_SRC/" "$SSH_HOST:$BACKEND_PATH/"

# 2. Загрузка веб-админки (build/web)
echo "[2/4] Syncing web (admin)..."
ssh "$SSH_HOST" "mkdir -p $WEB_PATH"
rsync -avz --delete \
  "$WEB_SRC/" "$SSH_HOST:$WEB_PATH/"

# 3. Добавить ADMIN_SECRET_KEY в .env на сервере, если его ещё нет
echo "[3/4] Ensure ADMIN_SECRET_KEY in .env..."
ADMIN_KEY="${ADMIN_SECRET_KEY:-donskih-admin-$(openssl rand -hex 16)}"
ssh "$SSH_HOST" "cd $BACKEND_PATH && (grep -q '^ADMIN_SECRET_KEY=' .env 2>/dev/null || echo \"ADMIN_SECRET_KEY=$ADMIN_KEY\" >> .env); echo 'ADMIN_SECRET_KEY is set'"

# 4. Миграции и перезапуск API
echo "[4/4] Migrate and restart API..."
ssh "$SSH_HOST" "cd $BACKEND_PATH && docker compose exec -T api alembic upgrade head 2>/dev/null || true && docker compose down && docker compose up -d"

echo ""
echo "=== Done ==="
echo "  API:  https://donskih-cdn.ru/api/v1/health"
echo "  Admin: https://donskih-cdn.ru/admin  (if nginx serves $WEB_PATH for /admin)"
echo "  Save this key for admin login: $ADMIN_KEY"
